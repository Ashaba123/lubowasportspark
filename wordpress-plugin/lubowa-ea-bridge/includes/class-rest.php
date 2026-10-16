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
                'permission_callback' => array(__CLASS__, 'require_login'),
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

    public static function get_services() {
        $services = Lubowa_EA_Booking_Service::list_services();
        return is_wp_error($services) ? $services : rest_ensure_response($services);
    }

    public static function get_slots(WP_REST_Request $request) {
        $date = self::valid_date($request->get_param('date'));
        if (is_wp_error($date)) {
            return $date;
        }
        $slots = Lubowa_EA_Booking_Service::slots((int) $request->get_param('service_id'), $date);
        if (is_wp_error($slots)) {
            return $slots;
        }
        return rest_ensure_response(array(
            'date'       => $date,
            'service_id' => (int) $request->get_param('service_id'),
            'slots'      => $slots,
        ));
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

        $user = wp_get_current_user();
        $name = sanitize_text_field((string) $request->get_param('contact_name'));
        $contact = array(
            'name'  => $name !== '' ? $name : $user->display_name,
            'email' => $user->user_email,
            'phone' => sanitize_text_field((string) $request->get_param('contact_phone')),
        );
        $notes = sanitize_textarea_field((string) $request->get_param('notes'));
        $notes = trim('Booked via app. ' . $notes);

        $created = Lubowa_EA_Booking_Service::book(
            $service_id,
            array($date),
            $time,
            $contact,
            $notes,
            Lubowa_EA_Settings::get('status_pending')
        );
        if (is_wp_error($created)) {
            return $created;
        }

        $item = Lubowa_EA_Booking_Service::to_booking_item($created[0], $contact['name']);
        return new WP_REST_Response($item, 201);
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
