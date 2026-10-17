<?php

if (!defined('ABSPATH')) {
    exit;
}

class Lubowa_EA_Rest {
    const NS = 'lubowa-ea/v1';
    const MAX_LEAGUE_WEEKS = 12;

    public static function register_routes() {
        register_rest_route(self::NS, '/services', array(
            'methods'             => 'GET',
            'callback'            => array(__CLASS__, 'get_services'),
            'permission_callback' => '__return_true',
        ));

        register_rest_route(self::NS, '/slots', array(
            'methods'             => 'GET',
            'callback'            => array(__CLASS__, 'get_slots'),
            'permission_callback' => '__return_true',
            'args'                => array(
                'service_id' => array('required' => true, 'type' => 'integer'),
                'date'       => array('required' => true, 'type' => 'string'),
            ),
        ));

        register_rest_route(self::NS, '/bookings', array(
            array(
                'methods'             => 'GET',
                'callback'            => array(__CLASS__, 'get_my_bookings'),
                'permission_callback' => array(__CLASS__, 'require_login'),
            ),
            array(
                'methods'             => 'POST',
                'callback'            => array(__CLASS__, 'create_booking'),
                'permission_callback' => array(__CLASS__, 'allow_guest'),
            ),
        ));

        register_rest_route(self::NS, '/bookings/guest', array(
            'methods'             => 'GET',
            'callback'            => array(__CLASS__, 'get_guest_bookings'),
            'permission_callback' => '__return_true',
        ));

        register_rest_route(self::NS, '/holds', array(
            array(
                'methods'             => 'POST',
                'callback'            => array(__CLASS__, 'create_hold'),
                'permission_callback' => '__return_true',
            ),
            array(
                'methods'             => 'DELETE',
                'callback'            => array(__CLASS__, 'delete_hold'),
                'permission_callback' => '__return_true',
            ),
        ));

        register_rest_route(self::NS, '/leagues/(?P<id>\d+)/bookings', array(
            array(
                'methods'             => 'GET',
                'callback'            => array(__CLASS__, 'get_league_bookings'),
                'permission_callback' => '__return_true',
            ),
            array(
                'methods'             => 'POST',
                'callback'            => array(__CLASS__, 'create_league_bookings'),
                'permission_callback' => array(__CLASS__, 'require_login'),
            ),
        ));
    }

    public static function require_login() {
        if (!is_user_logged_in()) {
            return new WP_Error('rest_forbidden', 'Please log in to book.', array('status' => 401));
        }
        // Same block flag the Lubowa API plugin sets from its App Users admin page.
        $blocked = get_user_meta(get_current_user_id(), 'lubowa_blocked', true);
        if ($blocked === '1' || $blocked === true) {
            return new WP_Error('rest_forbidden', 'Your account is blocked. Please contact Lubowa Sports Park.', array('status' => 403));
        }
        return true;
    }

    /** Booking is open to guests; a logged-in but blocked account is still refused. */
    public static function allow_guest() {
        return is_user_logged_in() ? self::require_login() : true;
    }

    /** Fixed-window limit per client IP. */
    private static function rate_limit($bucket, $max, $window) {
        $ip = isset($_SERVER['REMOTE_ADDR']) ? (string) $_SERVER['REMOTE_ADDR'] : '';
        $key = 'lubowa_ea_rl_' . md5($bucket . '|' . $ip);
        $count = (int) get_transient($key);
        if ($count >= $max) {
            return new WP_Error('rate_limited', 'Too many requests. Please try again later.', array('status' => 429));
        }
        set_transient($key, $count + 1, $window);
        return true;
    }

    public static function get_services() {
        $services = Lubowa_EA_Booking_Service::list_services();
        return is_wp_error($services) ? $services : rest_ensure_response($services);
    }

    public static function get_slots(WP_REST_Request $request) {
        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $slots = Lubowa_EA_Booking_Service::slots(
            (int) $request->get_param('service_id'),
            $date,
            Lubowa_EA_Holds::valid_device_id($request->get_param('device_id'))
        );
        if (is_wp_error($slots)) {
            return $slots;
        }
        $response = rest_ensure_response(array(
            'date'       => $date,
            'service_id' => (int) $request->get_param('service_id'),
            'slots'      => $slots,
        ));
        $response->header('Cache-Control', 'no-store');
        return $response;
    }

    public static function create_hold(WP_REST_Request $request) {
        $limited = self::rate_limit('hold', 60, 600);
        if (is_wp_error($limited)) {
            return $limited;
        }
        $device_id = Lubowa_EA_Holds::valid_device_id($request->get_param('device_id'));
        if ($device_id === null) {
            return new WP_Error('invalid_device', 'Invalid device.', array('status' => 400));
        }
        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $time = self::valid_time($request->get_param('time'));
        if (is_wp_error($time)) {
            return $time;
        }
        $service_id = (int) $request->get_param('service_id');
        if ($service_id <= 0) {
            return new WP_Error('invalid_service', 'Please select a service.', array('status' => 400));
        }
        $hold = Lubowa_EA_Holds::place($device_id, $service_id, $date, $time);
        return is_wp_error($hold) ? $hold : new WP_REST_Response($hold, 201);
    }

    public static function delete_hold(WP_REST_Request $request) {
        $device_id = Lubowa_EA_Holds::valid_device_id($request->get_param('device_id'));
        if ($device_id === null) {
            return new WP_Error('invalid_device', 'Invalid device.', array('status' => 400));
        }
        $released = Lubowa_EA_Holds::release($device_id);
        return is_wp_error($released) ? $released : new WP_REST_Response(null, 204);
    }

    /** Status of bookings this device made, by the tokens returned at creation. No contact details. */
    public static function get_guest_bookings(WP_REST_Request $request) {
        global $wpdb;
        $limited = self::rate_limit('guest', 120, 600);
        if (is_wp_error($limited)) {
            return $limited;
        }
        $tokens = array_slice(array_filter(array_map(function ($t) {
            $t = strtolower(trim($t));
            return preg_match('/^[a-f0-9]{32}$/', $t) ? $t : null;
        }, explode(',', (string) $request->get_param('tokens')))), 0, 50);

        $table = $wpdb->prefix . 'lubowa_ea_guest_tokens';
        $items = array();
        foreach (array_unique($tokens) as $token) {
            $row = $wpdb->get_row($wpdb->prepare(
                "SELECT * FROM $table WHERE token_hash = %s",
                hash('sha256', $token)
            ), ARRAY_A);
            if (!$row) {
                continue;
            }
            $appointment = Lubowa_EA_Client::get_appointment((int) $row['ea_appointment_id']);
            if (is_wp_error($appointment)) {
                $data = $appointment->get_error_data();
                if (!is_array($data) || (int) ($data['ea_status'] ?? 0) !== 404) {
                    return $appointment;
                }
                $service = Lubowa_EA_Booking_Service::find_service($row['service_id']);
                $item = array(
                    'id'           => (int) $row['ea_appointment_id'],
                    'date'         => substr($row['start_datetime'], 0, 10),
                    'time_slot'    => substr($row['start_datetime'], 11, 5),
                    'contact_name' => '',
                    'status'       => 'cancelled',
                    'service'      => is_wp_error($service) ? null : (string) $service['name'],
                    'service_id'   => (int) $row['service_id'],
                );
            } else {
                $item = Lubowa_EA_Booking_Service::to_booking_item($appointment);
            }
            $item['guest_token'] = $token;
            $items[] = $item;
        }

        $response = rest_ensure_response(array('data' => $items));
        $response->header('Cache-Control', 'no-store');
        return $response;
    }

    public static function get_my_bookings() {
        $user = wp_get_current_user();
        $items = Lubowa_EA_Booking_Service::customer_appointments($user->user_email);
        if (is_wp_error($items)) {
            return $items;
        }
        usort($items, function ($a, $b) {
            return strcmp($b['date'] . $b['time_slot'], $a['date'] . $a['time_slot']);
        });
        return rest_ensure_response(array('data' => $items));
    }

    public static function create_booking(WP_REST_Request $request) {
        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $time = self::valid_time($request->get_param('time'));
        if (is_wp_error($time)) {
            return $time;
        }
        $service_id = (int) $request->get_param('service_id');
        if ($service_id <= 0) {
            return new WP_Error('invalid_service', 'Please select a service.', array('status' => 400));
        }

        $name = sanitize_text_field((string) $request->get_param('contact_name'));
        if ($name === '') {
            return new WP_Error('invalid_name', 'Please enter your name.', array('status' => 400));
        }
        $phone = Lubowa_EA_Booking_Service::normalize_phone($request->get_param('contact_phone'));
        if ($phone === null) {
            return new WP_Error('invalid_phone', 'Please enter a valid phone number.', array('status' => 400));
        }

        $limited = self::rate_limit('book', 5, HOUR_IN_SECONDS);
        if (is_wp_error($limited)) {
            return $limited;
        }

        // Logged-in: the account email. Guest: their email if given, else one derived from the phone,
        // so the same phone always maps to the same EA customer. Guests never overwrite an existing
        // customer's details.
        $logged_in = is_user_logged_in();
        $email = sanitize_email((string) $request->get_param('contact_email'));
        if ($logged_in) {
            $email = wp_get_current_user()->user_email;
        } elseif ($email === '' || !is_email($email)) {
            $email = $phone . '@' . Lubowa_EA_Settings::get('guest_email_domain');
        }
        $contact = array('name' => $name, 'email' => $email, 'phone' => '+' . $phone);
        $notes = sanitize_textarea_field((string) $request->get_param('notes'));
        $notes = trim('Booked via app' . ($logged_in ? '' : ' (guest)') . '. ' . $notes);

        $created = Lubowa_EA_Booking_Service::book(
            $service_id,
            array($date),
            $time,
            $contact,
            $notes,
            Lubowa_EA_Settings::get('status_pending'),
            Lubowa_EA_Holds::valid_device_id($request->get_param('device_id')),
            $logged_in
        );
        if (is_wp_error($created)) {
            return $created;
        }

        $item = Lubowa_EA_Booking_Service::to_booking_item($created[0], $contact['name']);
        $item['guest_token'] = self::issue_guest_token($created[0], $service_id);
        return new WP_REST_Response($item, 201);
    }

    private static function issue_guest_token(array $appointment, $service_id) {
        global $wpdb;
        $token = bin2hex(random_bytes(16));
        $wpdb->insert($wpdb->prefix . 'lubowa_ea_guest_tokens', array(
            'token_hash'        => hash('sha256', $token),
            'ea_appointment_id' => (int) $appointment['id'],
            'service_id'        => (int) $service_id,
            'start_datetime'    => (string) $appointment['start'],
            'created_at'        => current_time('mysql'),
        ));
        return $token;
    }

    public static function get_league_bookings(WP_REST_Request $request) {
        global $wpdb;
        $table = $wpdb->prefix . 'lubowa_ea_league_bookings';
        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT ea_appointment_id, start_datetime FROM $table WHERE league_id = %d ORDER BY start_datetime ASC",
            (int) $request['id']
        ), ARRAY_A);

        $items = array_map(function ($row) {
            return array(
                'appointment_id' => (int) $row['ea_appointment_id'],
                'date'           => substr($row['start_datetime'], 0, 10),
                'time'           => substr($row['start_datetime'], 11, 5),
            );
        }, (array) $rows);

        return rest_ensure_response(array('data' => $items));
    }

    public static function create_league_bookings(WP_REST_Request $request) {
        global $wpdb;
        $league_id = (int) $request['id'];

        $league_name = self::own_league_name($league_id);
        if ($league_name === null) {
            return new WP_Error('league_not_found', 'League not found.', array('status' => 404));
        }

        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $time = self::valid_time($request->get_param('time'));
        if (is_wp_error($time)) {
            return $time;
        }
        $service_id = (int) $request->get_param('service_id');
        if ($service_id <= 0) {
            return new WP_Error('invalid_service', 'Please select a service.', array('status' => 400));
        }
        $weeks = (int) $request->get_param('weeks');
        if ($weeks < 1 || $weeks > self::MAX_LEAGUE_WEEKS) {
            return new WP_Error('invalid_weeks', 'Weeks must be between 1 and ' . self::MAX_LEAGUE_WEEKS . '.', array('status' => 400));
        }

        $dates = array();
        $cursor = new DateTime($date, Lubowa_EA_Settings::timezone());
        for ($i = 0; $i < $weeks; $i++) {
            $dates[] = $cursor->format('Y-m-d');
            $cursor->modify('+7 days');
        }

        $user = wp_get_current_user();
        $contact = array(
            'name'  => $user->display_name,
            'email' => $user->user_email,
            'phone' => sanitize_text_field((string) $request->get_param('contact_phone')),
        );
        $notes = sprintf('League: %s (#%d)', $league_name, $league_id);

        $created = Lubowa_EA_Booking_Service::book(
            $service_id,
            $dates,
            $time,
            $contact,
            $notes,
            Lubowa_EA_Settings::get('status_pending')
        );
        if (is_wp_error($created)) {
            return $created;
        }

        $table = $wpdb->prefix . 'lubowa_ea_league_bookings';
        $now = current_time('mysql');
        $items = array();
        foreach ($created as $appointment) {
            $wpdb->insert($table, array(
                'league_id'         => $league_id,
                'ea_appointment_id' => (int) $appointment['id'],
                'start_datetime'    => (string) $appointment['start'],
                'created_by'        => get_current_user_id(),
                'created_at'        => $now,
            ));
            $items[] = array(
                'appointment_id' => (int) $appointment['id'],
                'date'           => substr((string) $appointment['start'], 0, 10),
                'time'           => substr((string) $appointment['start'], 11, 5),
            );
        }

        return new WP_REST_Response(array('data' => $items), 201);
    }

    /**
     * League name if the current user may manage it (admin or creator, per the Lubowa API plugin's
     * lubowa_can_manage_league), else null.
     */
    private static function own_league_name($league_id) {
        global $wpdb;
        if (!function_exists('lubowa_can_manage_league') || !defined('LUBOWA_LEAGUES_TABLE')) {
            return null;
        }
        if (!lubowa_can_manage_league($league_id)) {
            return null;
        }
        $name = $wpdb->get_var($wpdb->prepare('SELECT name FROM ' . LUBOWA_LEAGUES_TABLE . ' WHERE id = %d', (int) $league_id));
        return $name === null ? null : (string) $name;
    }

    /**
     * Sends legacy app builds' POST /lubowa/v1/bookings and GET /lubowa/v1/bookings/slots
     * to EA so they share one calendar. Off until enabled in the bridge settings.
     */
    public static function intercept_legacy($result, $server, $request) {
        if ($result !== null || !Lubowa_EA_Settings::get('intercept_legacy')) {
            return $result;
        }
        $route = untrailingslashit($request->get_route());
        $method = $request->get_method();

        if ($route === '/lubowa/v1/bookings' && $method === 'POST') {
            return self::legacy_create($request);
        }
        if ($route === '/lubowa/v1/bookings/slots' && $method === 'GET') {
            return self::legacy_slots($request);
        }
        return $result;
    }

    private static function legacy_create(WP_REST_Request $request) {
        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $time = self::valid_time($request->get_param('time_slot'));
        if (is_wp_error($time)) {
            return $time;
        }
        $service = Lubowa_EA_Booking_Service::find_service_by_name($request->get_param('service'));
        if (is_wp_error($service)) {
            return $service;
        }
        $contact = array(
            'name'  => sanitize_text_field((string) $request->get_param('contact_name')),
            'email' => sanitize_email((string) $request->get_param('contact_email')),
            'phone' => sanitize_text_field((string) $request->get_param('contact_phone')),
        );
        $notes = trim('Booked via app (legacy). ' . sanitize_textarea_field((string) $request->get_param('notes')));

        $created = Lubowa_EA_Booking_Service::book(
            (int) $service['id'],
            array($date),
            $time,
            $contact,
            $notes,
            Lubowa_EA_Settings::get('status_pending')
        );
        if (is_wp_error($created)) {
            return $created;
        }
        return new WP_REST_Response(array('id' => (int) $created[0]['id'], 'status' => 'pending'), 201);
    }

    private static function legacy_slots(WP_REST_Request $request) {
        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $service = Lubowa_EA_Booking_Service::find_service_by_name($request->get_param('service'));
        if (is_wp_error($service)) {
            return $service;
        }
        $slots = Lubowa_EA_Booking_Service::slots((int) $service['id'], $date);
        if (is_wp_error($slots)) {
            return $slots;
        }
        $taken = array();
        foreach ($slots as $slot) {
            if ($slot['status'] !== 'available') {
                $taken[] = array('time_slot' => $slot['time'], 'status' => 'pending');
            }
        }
        return rest_ensure_response($taken);
    }

    private static function valid_date($value) {
        $value = (string) $value;
        $parsed = DateTime::createFromFormat('!Y-m-d', $value, Lubowa_EA_Settings::timezone());
        if (!$parsed || $parsed->format('Y-m-d') !== $value) {
            return new WP_Error('invalid_date', 'Invalid date.', array('status' => 400));
        }
        $today = new DateTime('today', Lubowa_EA_Settings::timezone());
        if ($parsed < $today) {
            return new WP_Error('invalid_date', 'Date is in the past.', array('status' => 400));
        }
        return $value;
    }

    private static function valid_time($value) {
        $value = (string) $value;
        if (!preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $value)) {
            return new WP_Error('invalid_time', 'Invalid time.', array('status' => 400));
        }
        return $value;
    }
}
