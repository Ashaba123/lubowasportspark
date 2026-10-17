<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Short-lived slot holds while an app user fills in booking details. Each hold is a real EA
 * appointment with the hold status, so EA (and its own booking page) sees the slot as taken.
 * One hold per device; expired holds are deleted from EA by purge_expired().
 */
class Lubowa_EA_Holds {
    public static function table() {
        global $wpdb;
        return $wpdb->prefix . 'lubowa_ea_holds';
    }

    public static function valid_device_id($value) {
        $value = strtolower((string) $value);
        return preg_match('/^[a-f0-9]{32,64}$/', $value) ? $value : null;
    }

    public static function device_hash($device_id) {
        return hash('sha256', (string) $device_id);
    }

    public static function find_by_device($device_id) {
        global $wpdb;
        if ($device_id === null) {
            return null;
        }
        $row = $wpdb->get_row($wpdb->prepare(
            'SELECT * FROM ' . self::table() . ' WHERE device_hash = %s',
            self::device_hash($device_id)
        ), ARRAY_A);
        return $row ?: null;
    }

    public static function minutes() {
        return max(1, (int) Lubowa_EA_Settings::get('hold_minutes'));
    }

    /** @return array|WP_Error {expires_at, expires_in} */
    public static function place($device_id, $service_id, $date, $time) {
        global $wpdb;
        self::purge_expired();

        $start = $date . ' ' . $time . ':00';
        $existing = self::find_by_device($device_id);
        if ($existing !== null) {
            if ((int) $existing['service_id'] === (int) $service_id && $existing['start_datetime'] === $start) {
                return self::extend($existing);
            }
            $released = self::release($device_id);
            if (is_wp_error($released)) {
                return $released;
            }
        }

        $created = Lubowa_EA_Booking_Service::create_hold($service_id, $date, $time);
        if (is_wp_error($created)) {
            return $created;
        }

        $expires = gmdate('Y-m-d H:i:s', time() + self::minutes() * 60);
        $inserted = $wpdb->insert(self::table(), array(
            'device_hash'       => self::device_hash($device_id),
            'ea_appointment_id' => (int) $created['appointment']['id'],
            'provider_id'       => (int) $created['provider_id'],
            'service_id'        => (int) $service_id,
            'start_datetime'    => $start,
            'expires_at'        => $expires,
        ));
        if ($inserted === false) {
            // A parallel request from the same device won the unique key; drop ours so EA has no untracked hold.
            Lubowa_EA_Client::delete_appointment((int) $created['appointment']['id']);
            return new WP_Error('hold_conflict', 'Please try again.', array('status' => 409));
        }
        return self::expiry($expires);
    }

    public static function release($device_id) {
        $row = self::find_by_device($device_id);
        if ($row === null) {
            return true;
        }
        return self::delete_hold($row);
    }

    /**
     * Holds of this device matching the slot, for converting into a booking. Caller holds the
     * provider lock, so purge cannot delete it in between.
     */
    public static function claimable($device_id, $service_id, $date, $time) {
        $row = self::find_by_device($device_id);
        if ($row === null) {
            return null;
        }
        if ((int) $row['service_id'] !== (int) $service_id || $row['start_datetime'] !== $date . ' ' . $time . ':00') {
            return null;
        }
        return $row;
    }

    public static function forget($row) {
        global $wpdb;
        $wpdb->delete(self::table(), array('id' => (int) $row['id']));
    }

    public static function purge_expired() {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . self::table() . ' WHERE expires_at < %s',
            gmdate('Y-m-d H:i:s')
        ), ARRAY_A);
        foreach ((array) $rows as $row) {
            Lubowa_EA_Booking_Service::with_lock((int) $row['provider_id'], function () use ($row, $wpdb) {
                $still = $wpdb->get_var($wpdb->prepare(
                    'SELECT id FROM ' . self::table() . ' WHERE id = %d AND expires_at < %s',
                    (int) $row['id'],
                    gmdate('Y-m-d H:i:s')
                ));
                if ($still) {
                    self::delete_hold($row);
                }
                return true;
            });
        }
    }

    private static function delete_hold(array $row) {
        $deleted = Lubowa_EA_Client::delete_appointment((int) $row['ea_appointment_id']);
        if (is_wp_error($deleted) && (int) self::ea_status($deleted) !== 404) {
            return $deleted;
        }
        self::forget($row);
        return true;
    }

    private static function extend(array $row) {
        global $wpdb;
        $expires = gmdate('Y-m-d H:i:s', time() + self::minutes() * 60);
        $wpdb->update(self::table(), array('expires_at' => $expires), array('id' => (int) $row['id']));
        return self::expiry($expires);
    }

    private static function expiry($expires_gmt) {
        return array(
            'expires_at' => gmdate('c', strtotime($expires_gmt . ' UTC')),
            'expires_in' => max(0, strtotime($expires_gmt . ' UTC') - time()),
        );
    }

    private static function ea_status(WP_Error $error) {
        $data = $error->get_error_data();
        return is_array($data) && isset($data['ea_status']) ? $data['ea_status'] : 0;
    }
}
