<?php

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Thin wrapper over the Easy!Appointments REST API v1.
 * Note: EA's POST /appointments does NOT check for overlaps; callers must lock + re-check.
 */
class Lubowa_EA_Client {
    const CACHE_TTL = 300;

    public static function request($method, $path, array $query = array(), $body = null) {
        $base = rtrim((string) Lubowa_EA_Settings::get('base_url'), '/');
        $token = (string) Lubowa_EA_Settings::get('token');
        if ($base === '' || $token === '') {
            return new WP_Error('ea_not_configured', 'Booking system is not configured.', array('status' => 503));
        }

        $url = $base . '/' . ltrim($path, '/');
        if (!empty($query)) {
            $url = add_query_arg(array_map('rawurlencode', $query), $url);
        }

        $args = array(
            'method'  => $method,
            'timeout' => 20,
            'headers' => array(
                'Authorization' => 'Bearer ' . $token,
                'Accept'        => 'application/json',
                'Content-Type'  => 'application/json',
            ),
        );
        if ($body !== null) {
            $args['body'] = wp_json_encode($body);
        }

        $response = wp_remote_request($url, $args);
        if (is_wp_error($response)) {
            return new WP_Error('ea_unreachable', 'Booking system unreachable.', array('status' => 502));
        }

        $code = (int) wp_remote_retrieve_response_code($response);
        $data = json_decode(wp_remote_retrieve_body($response), true);

        if ($code < 200 || $code >= 300) {
            $message = is_array($data) && isset($data['message']) ? (string) $data['message'] : 'Booking system error.';
            return new WP_Error('ea_http_' . $code, $message, array('status' => 502, 'ea_status' => $code));
        }

        return $data === null ? array() : $data;
    }

    public static function services() {
        $cached = get_transient('lubowa_ea_services');
        if (is_array($cached)) {
            return $cached;
        }
        $data = self::request('GET', 'services', array('length' => 500, 'page' => 1));
        if (is_wp_error($data)) {
            return $data;
        }
        set_transient('lubowa_ea_services', $data, self::CACHE_TTL);
        return $data;
    }

    public static function providers() {
        $cached = get_transient('lubowa_ea_providers');
        if (is_array($cached)) {
            return $cached;
        }
        $data = self::request('GET', 'providers', array('length' => 500, 'page' => 1));
        if (is_wp_error($data)) {
            return $data;
        }
        set_transient('lubowa_ea_providers', $data, self::CACHE_TTL);
        return $data;
    }

    public static function flush_cache() {
        delete_transient('lubowa_ea_services');
        delete_transient('lubowa_ea_providers');
    }

    /** @return string[]|WP_Error Free start times "HH:MM". */
    public static function availabilities($provider_id, $service_id, $date) {
        $data = self::request('GET', 'availabilities', array(
            'providerId' => (string) $provider_id,
            'serviceId'  => (string) $service_id,
            'date'       => $date,
        ));
        if (is_wp_error($data)) {
            return $data;
        }
        return array_values(array_filter(array_map('strval', (array) $data)));
    }

    public static function appointments(array $filters) {
        $query = array_merge(array('length' => 1000, 'page' => 1), $filters);
        return self::request('GET', 'appointments', $query);
    }

    public static function create_appointment(array $appointment) {
        return self::request('POST', 'appointments', array(), $appointment);
    }

    public static function get_appointment($id) {
        return self::request('GET', 'appointments/' . (int) $id);
    }

    public static function update_appointment($id, array $appointment) {
        return self::request('PUT', 'appointments/' . (int) $id, array(), $appointment);
    }

    public static function delete_appointment($id) {
        return self::request('DELETE', 'appointments/' . (int) $id);
    }

    public static function find_customer_by_email($email) {
        $data = self::request('GET', 'customers', array('q' => $email, 'length' => 50, 'page' => 1));
        if (is_wp_error($data)) {
            return $data;
        }
        foreach ((array) $data as $customer) {
            if (isset($customer['email']) && strcasecmp((string) $customer['email'], $email) === 0) {
                return $customer;
            }
        }
        return null;
    }

    public static function create_customer(array $customer) {
        return self::request('POST', 'customers', array(), $customer);
    }

    public static function update_customer($id, array $customer) {
        return self::request('PUT', 'customers/' . (int) $id, array(), $customer);
    }
}
