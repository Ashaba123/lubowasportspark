<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Booking rules: one EA provider per physical resource, slot grid from the provider's
 * working plan, and a MySQL named lock per provider around re-check + create so two
 * bridge requests can never book the same slot.
 */
class Lubowa_EA_Booking_Service {
    const LOCK_TIMEOUT = 15;

    public static function list_services() {
        $services = Lubowa_EA_Client::services();
        if (is_wp_error($services)) {
            return $services;
        }
        $providers = Lubowa_EA_Client::providers();
        if (is_wp_error($providers)) {
            return $providers;
        }
        $out = array();
        foreach ((array) $services as $service) {
            if (!empty($service['isPrivate'])) {
                continue;
            }
            if (self::provider_for_service((int) $service['id'], $providers) === null) {
                continue;
            }
            $out[] = array(
                'id'          => (int) $service['id'],
                'name'        => (string) $service['name'],
                'duration'    => (int) $service['duration'],
                'price'       => isset($service['price']) ? (string) $service['price'] : null,
                'currency'    => isset($service['currency']) ? (string) $service['currency'] : null,
                'description' => isset($service['description']) ? (string) $service['description'] : '',
            );
        }
        return $out;
    }

    public static function find_service($service_id) {
        $services = Lubowa_EA_Client::services();
        if (is_wp_error($services)) {
            return $services;
        }
        foreach ((array) $services as $service) {
            if ((int) $service['id'] === (int) $service_id) {
                return $service;
            }
        }
        return new WP_Error('service_not_found', 'Service not found.', array('status' => 404));
    }

    public static function find_service_by_name($name) {
        $services = Lubowa_EA_Client::services();
        if (is_wp_error($services)) {
            return $services;
        }
        $needle = strtolower(trim((string) $name));
        foreach ((array) $services as $service) {
            if (strtolower(trim((string) $service['name'])) === $needle) {
                return $service;
            }
        }
        return new WP_Error('service_not_found', 'Service not found.', array('status' => 404));
    }

    public static function provider_for_service($service_id, $providers = null) {
        if ($providers === null) {
            $providers = Lubowa_EA_Client::providers();
            if (is_wp_error($providers)) {
                return $providers;
            }
        }
        $matches = array();
        foreach ((array) $providers as $provider) {
            $ids = array_map('intval', isset($provider['services']) ? (array) $provider['services'] : array());
            if (in_array((int) $service_id, $ids, true)) {
                $matches[] = $provider;
            }
        }
        if (empty($matches)) {
            return null;
        }
        usort($matches, function ($a, $b) {
            return (int) $a['id'] - (int) $b['id'];
        });
        return $matches[0];
    }

    /**
     * There is one pitch: every bookable service must share one EA provider, or a 1h and a 2h
     * booking could overlap. Returns WP_Error when they are split.
     */
    public static function pitch_check() {
        $services = Lubowa_EA_Client::services();
        if (is_wp_error($services)) {
            return $services;
        }
        $providers = Lubowa_EA_Client::providers();
        if (is_wp_error($providers)) {
            return $providers;
        }
        $ids = array();
        foreach ((array) $services as $service) {
            if (!empty($service['isPrivate'])) {
                continue;
            }
            $provider = self::provider_for_service((int) $service['id'], $providers);
            if ($provider !== null) {
                $ids[(int) $provider['id']] = true;
            }
        }
        if (count($ids) > 1) {
            return new WP_Error('setup_error', 'Booking setup error: all services must use the same pitch (EA provider).', array('status' => 503));
        }
        return true;
    }

    /** @return array|WP_Error [service, provider] */
    private static function resolve($service_id) {
        $check = self::pitch_check();
        if (is_wp_error($check)) {
            return $check;
        }
        $service = self::find_service($service_id);
        if (is_wp_error($service)) {
            return $service;
        }
        $provider = self::provider_for_service($service_id);
        if (is_wp_error($provider)) {
            return $provider;
        }
        if ($provider === null) {
            return new WP_Error('no_provider', 'No resource is set up for this service.', array('status' => 409));
        }
        return array($service, $provider);
    }

    public static function with_lock($provider_id, callable $fn) {
        $lock = self::lock_name($provider_id);
        if (!self::acquire($lock)) {
            return new WP_Error('busy', 'Booking system busy, please try again.', array('status' => 503));
        }
        try {
            return $fn();
        } finally {
            self::release($lock);
        }
    }

    public static function is_hold(array $appointment) {
        return isset($appointment['status'])
            && strcasecmp(trim((string) $appointment['status']), (string) Lubowa_EA_Settings::get('status_hold')) === 0;
    }

    /**
     * Full slot grid for a date: available, booked, held (someone else is booking it),
     * mine (held by this device) or unavailable.
     */
    public static function slots($service_id, $date, $device_id = null) {
        Lubowa_EA_Holds::purge_expired();
        $resolved = self::resolve($service_id);
        if (is_wp_error($resolved)) {
            return $resolved;
        }
        list($service, $provider) = $resolved;

        $own = Lubowa_EA_Holds::find_by_device($device_id);
        $own_id = $own === null ? 0 : (int) $own['ea_appointment_id'];

        $duration = max(1, (int) $service['duration']);
        $plan = self::working_day($provider, $date);
        if ($plan === null) {
            return array();
        }

        $free = Lubowa_EA_Client::availabilities($provider['id'], $service_id, $date);
        if (is_wp_error($free)) {
            return $free;
        }
        $appointments = self::provider_appointments_on($provider['id'], $date);
        if (is_wp_error($appointments)) {
            return $appointments;
        }

        $step = max(5, (int) Lubowa_EA_Settings::get('slot_step'));
        $start = self::minutes($plan['start']);
        $end = self::minutes($plan['end']);
        $slots = array();

        for ($t = $start; $t + $duration <= $end; $t += $step) {
            $time = self::hhmm($t);
            $slots[] = array(
                'time'   => $time,
                'status' => in_array($time, $free, true) && !self::overlaps_any($t, $t + $duration, $appointments)
                    ? 'available'
                    : self::taken_status($t, $t + $duration, $appointments, $own_id, $date . ' ' . $time . ':00', (int) $service_id),
            );
        }

        return $slots;
    }

    /**
     * EA's free list alone is not enough: a service with more than one attendant lets EA offer a
     * time that is already booked. One pitch means any overlap is a clash.
     */
    private static function is_free($service, $provider, $service_id, $date, $time) {
        $free = Lubowa_EA_Client::availabilities($provider['id'], $service_id, $date);
        if (is_wp_error($free)) {
            return $free;
        }
        if (!in_array($time, $free, true)) {
            return false;
        }
        $appointments = self::provider_appointments_on($provider['id'], $date);
        if (is_wp_error($appointments)) {
            return $appointments;
        }
        $start = self::minutes($time);
        return !self::overlaps_any($start, $start + max(1, (int) $service['duration']), $appointments);
    }

    private static function taken_status($start_min, $end_min, array $appointments, $own_id, $start, $service_id) {
        $overlapping = array_filter($appointments, function ($a) use ($start_min, $end_min) {
            return self::overlaps_any($start_min, $end_min, array($a));
        });
        if (empty($overlapping)) {
            return 'unavailable';
        }
        foreach ($overlapping as $a) {
            if (!self::is_hold($a)) {
                return 'booked';
            }
        }
        if (count($overlapping) === 1) {
            $a = reset($overlapping);
            if ($own_id > 0 && (int) $a['id'] === $own_id
                && (string) $a['start'] === $start && (int) $a['serviceId'] === $service_id) {
                return 'mine';
            }
        }
        return 'held';
    }

    /** Creates a hold appointment if the slot is free. @return array|WP_Error {appointment, provider_id} */
    public static function create_hold($service_id, $date, $time) {
        $resolved = self::resolve($service_id);
        if (is_wp_error($resolved)) {
            return $resolved;
        }
        list($service, $provider) = $resolved;

        return self::with_lock($provider['id'], function () use ($service, $provider, $service_id, $date, $time) {
            $free = self::is_free($service, $provider, $service_id, $date, $time);
            if (is_wp_error($free)) {
                return $free;
            }
            if (!$free) {
                return new WP_Error('slot_taken', 'That time is no longer available.', array('status' => 409, 'dates' => array()));
            }
            $customer_id = self::upsert_customer(array(
                'name'  => 'App Hold',
                'email' => 'hold@' . Lubowa_EA_Settings::get('guest_email_domain'),
                // EA can require a phone on every customer.
                'phone' => '+256000000000',
            ), false);
            if (is_wp_error($customer_id)) {
                return $customer_id;
            }
            $appointment = self::new_appointment($service, $provider, $service_id, $date, $time, $customer_id,
                'App hold: someone is completing this booking.', Lubowa_EA_Settings::get('status_hold'));
            $created = Lubowa_EA_Client::create_appointment($appointment);
            if (is_wp_error($created)) {
                return $created;
            }
            return array('appointment' => $created, 'provider_id' => (int) $provider['id']);
        });
    }

    private static function new_appointment($service, $provider, $service_id, $date, $time, $customer_id, $notes, $status) {
        $tz = Lubowa_EA_Settings::timezone();
        $start = new DateTime($date . ' ' . $time . ':00', $tz);
        $end = clone $start;
        $end->modify('+' . (int) $service['duration'] . ' minutes');
        return array(
            'book'       => (new DateTime('now', $tz))->format('Y-m-d H:i:s'),
            'start'      => $start->format('Y-m-d H:i:s'),
            'end'        => $end->format('Y-m-d H:i:s'),
            'status'     => $status,
            'notes'      => (string) $notes,
            'customerId' => (int) $customer_id,
            'providerId' => (int) $provider['id'],
            'serviceId'  => (int) $service_id,
        );
    }

    /**
     * Create one appointment, or a series (league), under a provider lock.
     * All-or-nothing: every requested start must be free or nothing is created.
     *
     * A single-date booking from a device that holds that exact slot converts the hold
     * appointment instead of creating a new one.
     *
     * @param string[] $dates  Y-m-d dates, same start time on each.
     * @param bool $update_existing  Overwrite name/phone of an existing EA customer with this email.
     * @return array|WP_Error  Created EA appointments.
     */
    public static function book($service_id, array $dates, $time, array $contact, $notes, $status, $device_id = null, $update_existing = true) {
        Lubowa_EA_Holds::purge_expired();
        $resolved = self::resolve($service_id);
        if (is_wp_error($resolved)) {
            return $resolved;
        }
        list($service, $provider) = $resolved;

        return self::with_lock($provider['id'], function () use ($service, $provider, $service_id, $dates, $time, $contact, $notes, $status, $device_id, $update_existing) {
            $hold = count($dates) === 1 ? Lubowa_EA_Holds::claimable($device_id, $service_id, $dates[0], $time) : null;

            if ($hold === null) {
                $taken = array();
                foreach ($dates as $date) {
                    $free = self::is_free($service, $provider, $service_id, $date, $time);
                    if (is_wp_error($free)) {
                        return $free;
                    }
                    if (!$free) {
                        $taken[] = $date;
                    }
                }
                if (!empty($taken)) {
                    return new WP_Error('slot_taken', 'That time is no longer available.', array('status' => 409, 'dates' => $taken));
                }
            }

            $customer_id = self::upsert_customer($contact, $update_existing);
            if (is_wp_error($customer_id)) {
                return $customer_id;
            }

            if ($hold !== null) {
                $appointment = self::new_appointment($service, $provider, $service_id, $dates[0], $time, $customer_id, $notes, $status);
                $result = Lubowa_EA_Client::update_appointment((int) $hold['ea_appointment_id'], $appointment);
                if (is_wp_error($result)) {
                    return $result;
                }
                Lubowa_EA_Holds::forget($hold);
                return array($result);
            }

            $created = array();
            foreach ($dates as $date) {
                $result = Lubowa_EA_Client::create_appointment(
                    self::new_appointment($service, $provider, $service_id, $date, $time, $customer_id, $notes, $status)
                );
                if (is_wp_error($result)) {
                    foreach ($created as $done) {
                        Lubowa_EA_Client::delete_appointment($done['id']);
                    }
                    return $result;
                }
                $created[] = $result;
            }
            return $created;
        });
    }

    /** "0772 123456", "772123456", "+256 772 123456" → "256772123456"; null if not a phone number. */
    public static function normalize_phone($raw) {
        $digits = preg_replace('/\D/', '', (string) $raw);
        if (strlen($digits) === 10 && $digits[0] === '0') {
            $digits = '256' . substr($digits, 1);
        } elseif (strlen($digits) === 9 && $digits[0] === '7') {
            $digits = '256' . $digits;
        }
        $len = strlen($digits);
        return ($len >= 10 && $len <= 15) ? $digits : null;
    }

    public static function customer_appointments($email) {
        $customer = Lubowa_EA_Client::find_customer_by_email($email);
        if (is_wp_error($customer)) {
            return $customer;
        }
        if ($customer === null) {
            return array();
        }
        $data = Lubowa_EA_Client::appointments(array('customerId' => (string) $customer['id']));
        if (is_wp_error($data)) {
            return $data;
        }
        $mine = array_filter((array) $data, function ($a) use ($customer) {
            return isset($a['customerId']) && (int) $a['customerId'] === (int) $customer['id'];
        });
        $customer_name = trim($customer['firstName'] . ' ' . $customer['lastName']);
        return array_map(function ($a) use ($customer_name) {
            return self::to_booking_item($a, $customer_name);
        }, array_values($mine));
    }

    public static function to_booking_item(array $appointment, $contact_name = '') {
        $start = (string) $appointment['start'];
        $service_name = null;
        $service = self::find_service($appointment['serviceId']);
        if (!is_wp_error($service)) {
            $service_name = (string) $service['name'];
        }
        $status = strtolower(trim((string) (isset($appointment['status']) ? $appointment['status'] : '')));
        return array(
            'id'           => (int) $appointment['id'],
            'date'         => substr($start, 0, 10),
            'time_slot'    => substr($start, 11, 5),
            'end_time'     => substr((string) $appointment['end'], 11, 5),
            'contact_name' => $contact_name,
            'status'       => $status === '' ? 'pending' : $status,
            'service'      => $service_name,
            'service_id'   => (int) $appointment['serviceId'],
            'created_at'   => isset($appointment['book']) ? (string) $appointment['book'] : null,
        );
    }

    private static function upsert_customer(array $contact, $update_existing = true) {
        $email = sanitize_email($contact['email']);
        if ($email === '' || !is_email($email)) {
            return new WP_Error('invalid_email', 'A valid email is required.', array('status' => 400));
        }
        $parts = preg_split('/\s+/', trim((string) $contact['name']), 2);
        $first = isset($parts[0]) && $parts[0] !== '' ? $parts[0] : $email;
        $last = isset($parts[1]) && $parts[1] !== '' ? $parts[1] : '-';
        $phone = (string) $contact['phone'];

        $existing = Lubowa_EA_Client::find_customer_by_email($email);
        if (is_wp_error($existing)) {
            return $existing;
        }

        if ($existing === null) {
            $created = Lubowa_EA_Client::create_customer(array(
                'firstName' => $first,
                'lastName'  => $last,
                'email'     => $email,
                'phone'     => $phone,
                'timezone'  => Lubowa_EA_Settings::get('timezone'),
            ));
            return is_wp_error($created) ? $created : (int) $created['id'];
        }

        $changed = $update_existing && ($existing['firstName'] !== $first || $existing['lastName'] !== $last
            || ($phone !== '' && (string) $existing['phone'] !== $phone));
        if ($changed) {
            $existing['firstName'] = $first;
            $existing['lastName'] = $last;
            if ($phone !== '') {
                $existing['phone'] = $phone;
            }
            $updated = Lubowa_EA_Client::update_customer($existing['id'], $existing);
            if (is_wp_error($updated)) {
                return $updated;
            }
        }
        return (int) $existing['id'];
    }

    private static function working_day(array $provider, $date) {
        $settings = isset($provider['settings']) ? $provider['settings'] : array();
        $plan = self::decode(isset($settings['workingPlan']) ? $settings['workingPlan'] : array());
        $exceptions = self::decode(isset($settings['workingPlanExceptions']) ? $settings['workingPlanExceptions'] : array());

        if (array_key_exists($date, $exceptions)) {
            $day = $exceptions[$date];
        } else {
            $weekday = strtolower((new DateTime($date))->format('l'));
            $day = isset($plan[$weekday]) ? $plan[$weekday] : null;
        }

        if (!is_array($day) || empty($day['start']) || empty($day['end'])) {
            return null;
        }
        return $day;
    }

    private static function provider_appointments_on($provider_id, $date) {
        $data = Lubowa_EA_Client::appointments(array('providerId' => (string) $provider_id, 'date' => $date));
        if (is_wp_error($data)) {
            return $data;
        }
        return array_values(array_filter((array) $data, function ($a) use ($provider_id, $date) {
            return isset($a['providerId'], $a['start'])
                && (int) $a['providerId'] === (int) $provider_id
                && substr((string) $a['start'], 0, 10) === $date;
        }));
    }

    private static function overlaps_any($start_min, $end_min, array $appointments) {
        foreach ($appointments as $a) {
            $a_start = self::minutes(substr((string) $a['start'], 11, 5));
            $a_end = substr((string) $a['end'], 0, 10) === substr((string) $a['start'], 0, 10)
                ? self::minutes(substr((string) $a['end'], 11, 5))
                : 24 * 60;
            if ($a_start < $end_min && $a_end > $start_min) {
                return true;
            }
        }
        return false;
    }

    private static function decode($value) {
        if (is_string($value)) {
            $value = json_decode($value, true);
        }
        return is_array($value) ? $value : array();
    }

    private static function minutes($hhmm) {
        $parts = explode(':', (string) $hhmm);
        return ((int) $parts[0]) * 60 + (isset($parts[1]) ? (int) $parts[1] : 0);
    }

    private static function hhmm($minutes) {
        return sprintf('%02d:%02d', intdiv($minutes, 60), $minutes % 60);
    }

    private static function lock_name($provider_id) {
        global $wpdb;
        return substr('lubowa_ea_' . $wpdb->prefix . 'p' . (int) $provider_id, 0, 64);
    }

    private static function acquire($name) {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s, %d)', $name, self::LOCK_TIMEOUT)) === 1;
    }

    private static function release($name) {
        global $wpdb;
        $wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)', $name));
    }
}
