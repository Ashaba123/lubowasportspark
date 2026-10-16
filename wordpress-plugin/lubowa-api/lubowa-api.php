<?php
/**
 * Plugin Name: Lubowa Sports Park API
 * Description: Backend for the Lubowa Sports Park mobile app. Provides REST API for court bookings, league management (leagues, teams, players, fixtures, goals), app user signup and Google sign-in with JWT, and “my career goals”. Adds WordPress admin pages for App Bookings, Leagues, and App Users (view/block app-registered users). Requires JWT auth for protected endpoints.
 * Version: 1.5.0
 * Author: Ashaba Derrick
 */

if (!defined('ABSPATH')) {
    exit;
}

define('LUBOWA_API_NAMESPACE', 'lubowa/v1');
define('LUBOWA_TABLE_PREFIX', 'lubowa_');

global $wpdb;
define('LUBOWA_BOOKINGS_TABLE', $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'bookings');
define('LUBOWA_LEAGUES_TABLE', $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'leagues');
define('LUBOWA_TEAMS_TABLE', $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'teams');
define('LUBOWA_PLAYERS_TABLE', $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'players');
define('LUBOWA_FIXTURES_TABLE', $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'fixtures');
define('LUBOWA_GOALS_TABLE', $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'goals');

register_activation_hook(__FILE__, 'lubowa_api_create_tables');
register_activation_hook(__FILE__, 'lubowa_api_register_capability');

function lubowa_api_register_capability() {
    $admin = get_role('administrator');
    if ($admin && !$admin->has_cap('create_lubowa_league')) {
        $admin->add_cap('create_lubowa_league');
    }

    // Ensure dedicated app user role exists with league capability.
    $role = get_role('lubowa_app_user');
    if (!$role) {
        $role = add_role(
            'lubowa_app_user',
            'Lubowa App User',
            [
                'read' => true,
                'create_lubowa_league' => true,
            ]
        );
    } elseif ($role && !$role->has_cap('create_lubowa_league')) {
        $role->add_cap('create_lubowa_league');
    }
}

function lubowa_api_create_tables() {
    global $wpdb;
    $charset = $wpdb->get_charset_collate();
    $prefix  = $wpdb->prefix . LUBOWA_TABLE_PREFIX;

    require_once ABSPATH . 'wp-admin/includes/upgrade.php';

    $bookings = $prefix . 'bookings';
    dbDelta("CREATE TABLE $bookings (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        date date NOT NULL,
        time_slot varchar(100) NOT NULL,
        contact_name varchar(255) NOT NULL,
        contact_phone varchar(100) NOT NULL,
        contact_email varchar(255) NOT NULL,
        notes text,
        service varchar(255) NOT NULL DEFAULT '',
        status varchar(50) NOT NULL DEFAULT 'pending',
        created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY contact_email (contact_email),
        KEY date (date),
        UNIQUE KEY unique_slot (date, time_slot, service)
    ) $charset;");

    $leagues = $prefix . 'leagues';
    dbDelta("CREATE TABLE $leagues (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        name varchar(255) NOT NULL,
        code varchar(20) NOT NULL,
        legs int(11) NOT NULL DEFAULT 1,
        booking_id bigint(20) unsigned DEFAULT NULL,
        created_by bigint(20) unsigned DEFAULT NULL,
        created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY code (code),
        KEY created_by (created_by),
        KEY booking_id (booking_id)
    ) $charset;");

    $teams = $prefix . 'teams';
    dbDelta("CREATE TABLE $teams (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        league_id bigint(20) unsigned NOT NULL,
        name varchar(255) NOT NULL,
        leader_user_id bigint(20) unsigned DEFAULT NULL,
        created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY league_name (league_id, name),
        KEY league_id (league_id),
        KEY leader_user_id (leader_user_id)
    ) $charset;");

    $players = $prefix . 'players';
    dbDelta("CREATE TABLE $players (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        team_id bigint(20) unsigned NOT NULL,
        name varchar(255) NOT NULL,
        goals int(11) NOT NULL DEFAULT 0,
        user_id bigint(20) unsigned DEFAULT NULL,
        created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY team_id (team_id),
        KEY user_id (user_id)
    ) $charset;");

    $fixtures = $prefix . 'fixtures';
    dbDelta("CREATE TABLE $fixtures (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        league_id bigint(20) unsigned NOT NULL,
        home_team_id bigint(20) unsigned NOT NULL,
        away_team_id bigint(20) unsigned NOT NULL,
        home_goals int(11) DEFAULT NULL,
        away_goals int(11) DEFAULT NULL,
        result_confirmed tinyint(1) NOT NULL DEFAULT 0,
        match_date date DEFAULT NULL,
        match_time varchar(20) DEFAULT NULL,
        started_at datetime DEFAULT NULL,
        sort_order int(11) NOT NULL DEFAULT 0,
        created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY league_id (league_id),
        KEY match_date (match_date)
    ) $charset;");

    $goals = $prefix . 'goals';
    dbDelta("CREATE TABLE $goals (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        fixture_id bigint(20) unsigned NOT NULL,
        team_id bigint(20) unsigned NOT NULL,
        player_id bigint(20) unsigned NOT NULL,
        goals int(11) NOT NULL DEFAULT 0,
        created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY fixture_id (fixture_id),
        KEY player_id (player_id),
        KEY team_id (team_id)
    ) $charset;");

    update_option('lubowa_db_version', 5);
}

add_action('init', function () {
    global $wpdb;
    $t = $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'leagues';
    if (get_option('lubowa_db_version') < 2) {
        $wpdb->query("ALTER TABLE `$t` ADD COLUMN legs int(11) NOT NULL DEFAULT 1 AFTER code");
        update_option('lubowa_db_version', 2);
    }
    if (get_option('lubowa_db_version') < 3) {
        $wpdb->query("ALTER TABLE `$t` ADD COLUMN booking_id bigint(20) unsigned DEFAULT NULL AFTER legs, ADD KEY booking_id (booking_id)");
        update_option('lubowa_db_version', 3);
    }
    $bt = $wpdb->prefix . LUBOWA_TABLE_PREFIX . 'bookings';
    if (get_option('lubowa_db_version') < 4) {
        $wpdb->query("ALTER TABLE `$bt` ADD COLUMN service varchar(255) NOT NULL DEFAULT '' AFTER notes");
        update_option('lubowa_db_version', 4);
    }

    if (get_option('lubowa_db_version') < 6) {
        // Ensure that each (date, time_slot, service) combination can only be booked once.
        $wpdb->query("ALTER TABLE `$bt` ADD UNIQUE KEY unique_slot (date, time_slot, service)");
        update_option('lubowa_db_version', 6);
    }

    // v5: individual goal log table for per-goal PATCH/DELETE.
    if (get_option('lubowa_db_version') < 5) {
        $prefix = $wpdb->prefix . LUBOWA_TABLE_PREFIX;
        $goals  = $prefix . 'goals';
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        $charset = $wpdb->get_charset_collate();
        dbDelta("CREATE TABLE $goals (
            id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            fixture_id bigint(20) unsigned NOT NULL,
            team_id bigint(20) unsigned NOT NULL,
            player_id bigint(20) unsigned NOT NULL,
            goals int(11) NOT NULL DEFAULT 0,
            created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY fixture_id (fixture_id),
            KEY player_id (player_id),
            KEY team_id (team_id)
        ) $charset;");
        update_option('lubowa_db_version', 5);
    }
}, 1);

function lubowa_api_admin_permission() {
    return is_user_logged_in() && current_user_can('manage_options');
}

function lubowa_api_logged_in_permission() {
    if (!is_user_logged_in()) {
        return false;
    }
    $uid = get_current_user_id();
    if ($uid < 1) {
        return false;
    }
    $blocked = get_user_meta($uid, 'lubowa_blocked', true);
    return $blocked !== '1' && $blocked !== true;
}

/** Can create a new league (admin or has capability). */
function lubowa_can_create_league() {
    return is_user_logged_in() && (current_user_can('manage_options') || current_user_can('create_lubowa_league'));
}

/** Can manage this league (admin or league creator). */
function lubowa_can_manage_league($league_id) {
    if (!is_user_logged_in()) {
        return false;
    }
    if (current_user_can('manage_options')) {
        return true;
    }
    global $wpdb;
    $league = $wpdb->get_row($wpdb->prepare("SELECT created_by FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id));
    return $league && (int) $league->created_by === (int) get_current_user_id();
}

/** Can manage this team (admin, league creator, or team leader). */
function lubowa_can_manage_team($team_id) {
    if (!is_user_logged_in()) {
        return false;
    }
    if (current_user_can('manage_options')) {
        return true;
    }
    global $wpdb;
    $team = $wpdb->get_row($wpdb->prepare("SELECT t.league_id, t.leader_user_id, l.created_by FROM " . LUBOWA_TEAMS_TABLE . " t JOIN " . LUBOWA_LEAGUES_TABLE . " l ON t.league_id = l.id WHERE t.id = %d", $team_id));
    if (!$team) {
        return false;
    }
    $uid = get_current_user_id();
    return (int) $team->created_by === $uid || (int) $team->leader_user_id === $uid;
}

/** Can record goals in this fixture for the given team (admin, league manager, or that team's leader). */
function lubowa_can_record_goals_for_team_in_fixture($fixture_id, $team_id) {
    if (!is_user_logged_in()) {
        return false;
    }
    if (current_user_can('manage_options')) {
        return true;
    }
    global $wpdb;
    $f = $wpdb->get_row($wpdb->prepare("SELECT league_id FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $fixture_id));
    if (!$f) {
        return false;
    }
    if (lubowa_can_manage_league($f->league_id)) {
        return true;
    }
    $t = $wpdb->get_row($wpdb->prepare("SELECT leader_user_id FROM " . LUBOWA_TEAMS_TABLE . " WHERE id = %d", $team_id));
    return $t && (int) $t->leader_user_id === (int) get_current_user_id();
}

/** Pagination defaults for list endpoints. */
define('LUBOWA_API_PER_PAGE_DEFAULT', 20);
define('LUBOWA_API_PER_PAGE_MAX', 100);

/**
 * Return a REST error response with consistent envelope: { "error": { "code": "...", "message": "...", "details": [] } }.
 *
 * @param string $code    Machine-readable error code (e.g. league_not_found).
 * @param string $message Human-readable message.
 * @param int    $status  HTTP status (4xx or 5xx).
 * @param array  $details Optional extra fields (e.g. field-level validation).
 * @return WP_REST_Response
 */
function lubowa_api_error($code, $message, $status, $details = []) {
    $body = ['error' => array_merge(['code' => $code, 'message' => $message], $details ? ['details' => $details] : [])];
    return new WP_REST_Response($body, $status);
}

/**
 * Internal: request a JWT from the existing jwt-auth/v1/token endpoint for given credentials.
 *
 * Returns ['token' => string, 'user' => array] on success, or null on failure.
 */
function lubowa_api_issue_jwt_for_credentials($username, $password) {
    if (!class_exists('WP_REST_Request')) {
        return null;
    }
    $request = new WP_REST_Request('POST', '/jwt-auth/v1/token');
    $request->set_param('username', $username);
    $request->set_param('password', $password);
    $response = rest_do_request($request);
    if ($response->is_error()) {
        return null;
    }
    $status = $response->get_status();
    if ($status !== 200) {
        return null;
    }
    $data = $response->get_data();
    if (!is_array($data) || empty($data['token'])) {
        return null;
    }
    return [
        'token' => (string) $data['token'],
        'user'  => isset($data['user']) && is_array($data['user']) ? $data['user'] : [],
    ];
}

/**
 * POST /lubowa/v1/signup
 * Public signup for Lubowa app users. Creates a WordPress user with role lubowa_app_user.
 */
function lubowa_api_signup(WP_REST_Request $request) {
    $raw_email = trim((string) $request->get_param('email'));
    $raw_password = (string) $request->get_param('password');
    $raw_name = trim((string) $request->get_param('name'));
    $raw_username = trim((string) $request->get_param('username'));

    if (!is_email($raw_email)) {
        return lubowa_api_error('validation_error', 'Invalid email address', 422);
    }

    if (strlen($raw_password) < 8) {
        return lubowa_api_error('weak_password', 'Password must be at least 8 characters long', 422);
    }

    $email = sanitize_email($raw_email);
    $username = $raw_username !== '' ? sanitize_user($raw_username, true) : '';
    if ($username === '') {
        $base = sanitize_user(current(explode('@', $email)), true);
        if ($base === '') {
            $base = 'lubowa_user';
        }
        $username = $base;
        $suffix = 1;
        while (username_exists($username)) {
            $username = $base . $suffix;
            $suffix++;
        }
    } elseif (username_exists($username)) {
        return lubowa_api_error('username_in_use', 'Username already in use', 409);
    }

    if (email_exists($email)) {
        return lubowa_api_error('email_in_use', 'Email already in use', 409);
    }

    $user_data = [
        'user_login' => $username,
        'user_email' => $email,
        'user_pass'  => $raw_password,
        'role'       => 'lubowa_app_user',
    ];
    if ($raw_name !== '') {
        $user_data['display_name'] = $raw_name;
    }

    $user_id = wp_insert_user($user_data);
    if (is_wp_error($user_id)) {
        return lubowa_api_error('create_failed', 'Failed to create user', 500, ['wp_error' => $user_id->get_error_message()]);
    }

    $user = get_userdata($user_id);
    if (!$user) {
        return lubowa_api_error('create_failed', 'Failed to load created user', 500);
    }

    $user_payload = [
        'id'       => (int) $user_id,
        'email'    => $user->user_email,
        'username' => $user->user_login,
        'name'     => $user->display_name ?: $user->user_login,
        'roles'    => $user->roles,
    ];

    $jwt = lubowa_api_issue_jwt_for_credentials($user->user_login, $raw_password);
    if ($jwt && !empty($jwt['token'])) {
        return new WP_REST_Response(
            [
                'token' => $jwt['token'],
                'user'  => $user_payload,
            ],
            201
        );
    }

    // Fallback: user created but JWT plugin not available; client must log in separately.
    return new WP_REST_Response(
        [
            'token' => null,
            'user'  => $user_payload,
        ],
        201
    );
}

/**
 * POST /lubowa/v1/google_login
 * Verifies a Google ID token and logs in or creates a lubowa_app_user, returning a JWT.
 */
function lubowa_api_google_login(WP_REST_Request $request) {
    $id_token = trim((string) $request->get_param('id_token'));
    $display_name = trim((string) $request->get_param('display_name'));

    if ($id_token === '') {
        return lubowa_api_error('validation_error', 'Missing id_token', 422);
    }

    $response = wp_remote_get(
        add_query_arg(
            ['id_token' => rawurlencode($id_token)],
            'https://oauth2.googleapis.com/tokeninfo'
        ),
        ['timeout' => 10]
    );

    if (is_wp_error($response)) {
        return lubowa_api_error('google_token_error', 'Failed to verify Google token', 502, ['wp_error' => $response->get_error_message()]);
    }

    $code = (int) wp_remote_retrieve_response_code($response);
    $body = wp_remote_retrieve_body($response);
    $data = json_decode($body, true);
    if ($code !== 200 || !is_array($data)) {
        return lubowa_api_error('google_token_invalid', 'Invalid Google token', 401);
    }

    $aud = isset($data['aud']) ? (string) $data['aud'] : '';
    if (defined('LUBOWA_GOOGLE_CLIENT_ID') && LUBOWA_GOOGLE_CLIENT_ID !== '' && $aud !== LUBOWA_GOOGLE_CLIENT_ID) {
        return lubowa_api_error('google_audience_mismatch', 'Google token audience mismatch', 401);
    }

    $email = isset($data['email']) ? sanitize_email($data['email']) : '';
    $email_verified = isset($data['email_verified']) && ($data['email_verified'] === true || $data['email_verified'] === 'true' || $data['email_verified'] === '1');
    $sub = isset($data['sub']) ? (string) $data['sub'] : '';
    $name = $display_name !== '' ? $display_name : (isset($data['name']) ? sanitize_text_field($data['name']) : '');

    if ($email === '' || !$email_verified) {
        return lubowa_api_error('google_email_unverified', 'Google account email must be verified', 401);
    }
    if ($sub === '') {
        return lubowa_api_error('google_token_invalid', 'Google token missing subject', 401);
    }

    // Try to find existing user by google_sub meta, then by email.
    $user = null;
    $users = get_users([
        'meta_key'   => 'google_sub',
        'meta_value' => $sub,
        'number'     => 1,
        'count_total'=> false,
        'fields'     => 'all',
    ]);
    if (!empty($users)) {
        $user = $users[0];
    }
    if (!$user && $email !== '') {
        $user = get_user_by('email', $email);
    }

    if (!$user) {
        $base = sanitize_user(current(explode('@', $email)), true);
        if ($base === '') {
            $base = 'lubowa_user';
        }
        $username = $base;
        $suffix = 1;
        while (username_exists($username)) {
            $username = $base . $suffix;
            $suffix++;
        }

        $random_password = wp_generate_password(20, true, true);
        $user_data = [
            'user_login' => $username,
            'user_email' => $email,
            'user_pass'  => $random_password,
            'role'       => 'lubowa_app_user',
        ];
        if ($name !== '') {
            $user_data['display_name'] = $name;
        }
        $user_id = wp_insert_user($user_data);
        if (is_wp_error($user_id)) {
            return lubowa_api_error('create_failed', 'Failed to create user', 500, ['wp_error' => $user_id->get_error_message()]);
        }
        $user = get_userdata($user_id);
        if (!$user) {
            return lubowa_api_error('create_failed', 'Failed to load created user', 500);
        }
        update_user_meta($user->ID, 'google_sub', $sub);
    } else {
        $user_id = $user->ID;
        update_user_meta($user_id, 'google_sub', $sub);
        if (!in_array('lubowa_app_user', (array) $user->roles, true)) {
            $user->add_role('lubowa_app_user');
        }
    }

    // Ensure role still has league capability.
    $role = get_role('lubowa_app_user');
    if ($role && !$role->has_cap('create_lubowa_league')) {
        $role->add_cap('create_lubowa_league');
    }

    // Generate a temporary password to obtain a JWT; user always signs in with Google, not password.
    $temp_password = wp_generate_password(32, true, true);
    $updated = wp_update_user([
        'ID'        => $user_id,
        'user_pass' => $temp_password,
    ]);
    if (is_wp_error($updated)) {
        return lubowa_api_error('create_failed', 'Failed to prepare user for login', 500, ['wp_error' => $updated->get_error_message()]);
    }

    $jwt = lubowa_api_issue_jwt_for_credentials($user->user_login, $temp_password);
    if (!$jwt || empty($jwt['token'])) {
        return lubowa_api_error('auth_failed', 'Failed to obtain JWT for user', 500);
    }

    $user_payload = [
        'id'       => (int) $user_id,
        'email'    => $user->user_email,
        'username' => $user->user_login,
        'name'     => $user->display_name ?: $user->user_login,
        'roles'    => $user->roles,
    ];

    return new WP_REST_Response(
        [
            'token' => $jwt['token'],
            'user'  => $user_payload,
        ],
        200
    );
}

/**
 * Return a paginated list response: { "data": [], "meta": { "page", "per_page", "total" } }.
 */
function lubowa_api_paginated($data, $page, $per_page, $total) {
    return new WP_REST_Response([
        'data' => $data ?: [],
        'meta' => ['page' => (int) $page, 'per_page' => (int) $per_page, 'total' => (int) $total],
    ], 200);
}

/**
 * Prevent caching of Lubowa API responses so list endpoints (teams, players, fixtures, bookings)
 * always return fresh data after add/edit/delete/generate.
 */
function lubowa_api_no_cache_headers($response, $server, $request) {
    $route = $request->get_route();
    if ($route !== '' && strpos($route, LUBOWA_API_NAMESPACE) !== false) {
        $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
        $response->header('Pragma', 'no-cache');
    }
    return $response;
}
add_filter('rest_post_dispatch', 'lubowa_api_no_cache_headers', 10, 3);

add_action('rest_api_init', function () {
    register_rest_route(LUBOWA_API_NAMESPACE, '/signup', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_signup',
        'permission_callback' => '__return_true',
        'args'                => [
            'email'    => ['required' => true, 'type' => 'string', 'format' => 'email'],
            'password' => ['required' => true, 'type' => 'string'],
            'name'     => ['required' => false, 'type' => 'string'],
            'username' => ['required' => false, 'type' => 'string'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/google_login', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_google_login',
        'permission_callback' => '__return_true',
        'args'                => [
            'id_token'     => ['required' => true, 'type' => 'string'],
            'display_name' => ['required' => false, 'type' => 'string'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/bookings', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_booking_create',
        'permission_callback' => '__return_true',
        'args'                => [
            'date'          => ['required' => true, 'type' => 'string', 'format' => 'date'],
            'time_slot'     => ['required' => true, 'type' => 'string'],
            'contact_name'  => ['required' => true, 'type' => 'string'],
            'contact_phone'  => ['required' => true, 'type' => 'string'],
            'contact_email'  => ['required' => true, 'type' => 'string', 'format' => 'email'],
            'notes'         => ['required' => false, 'type' => 'string', 'default' => ''],
            'service'       => ['required' => false, 'type' => 'string', 'default' => ''],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/bookings', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_booking_list',
        'permission_callback' => '__return_true',
        'args'                => [
            'contact_email' => ['required' => true, 'type' => 'string', 'format' => 'email'],
            'page'          => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'default' => 1],
            'per_page'      => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => LUBOWA_API_PER_PAGE_MAX, 'default' => LUBOWA_API_PER_PAGE_DEFAULT],
            'sort'          => ['required' => false, 'type' => 'string', 'enum' => ['created_at', '-created_at'], 'default' => '-created_at'],
            'status'        => ['required' => false, 'type' => 'string', 'enum' => ['pending', 'approved', 'canceled', 'rejected']],
        ],
    ]);

    register_rest_route(LUBOWA_API_NAMESPACE, '/bookings/slots', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_booked_slots',
        'permission_callback' => '__return_true',
        'args'                => [
            'date'    => ['required' => true, 'type' => 'string', 'format' => 'date'],
            'service' => ['required' => true, 'type' => 'string'],
            'status'  => ['required' => false, 'type' => 'string', 'enum' => ['pending', 'approved', 'canceled', 'rejected']],
        ],
    ]);

    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_league_create',
        'permission_callback' => 'lubowa_can_create_league',
        'args'                => [
            'name'       => ['required' => true, 'type' => 'string'],
            'legs'       => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => 10],
            'booking_id' => ['required' => false, 'type' => 'integer'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_league_list',
        'permission_callback' => 'lubowa_api_logged_in_permission',
        'args'                => [
            'page'     => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'default' => 1],
            'per_page' => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => LUBOWA_API_PER_PAGE_MAX, 'default' => LUBOWA_API_PER_PAGE_DEFAULT],
            'sort'     => ['required' => false, 'type' => 'string', 'enum' => ['created_at', '-created_at', 'name', '-name'], 'default' => '-created_at'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)', [
        'methods'             => 'PATCH',
        'callback'            => 'lubowa_api_league_update',
        'permission_callback' => function ($request) { return lubowa_can_manage_league($request->get_param('id')); },
        'args'                => [
            'id'          => ['required' => true, 'type' => 'integer'],
            'name'        => ['required' => false, 'type' => 'string'],
            'code'        => ['required' => false, 'type' => 'string'],
            'legs'        => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => 10],
            'booking_id'  => ['required' => false, 'type' => 'integer'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)', [
        'methods'             => 'DELETE',
        'callback'            => 'lubowa_api_league_delete',
        'permission_callback' => function ($request) { return lubowa_can_manage_league($request->get_param('id')); },
        'args'                => ['id' => ['required' => true, 'type' => 'integer']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)/teams', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_league_teams_list',
        'permission_callback' => function ($request) {
            $league_id = (int) $request->get_param('id');
            if (lubowa_can_manage_league($league_id)) {
                return true;
            }
            global $wpdb;
            $uid = get_current_user_id();
            $t = $wpdb->get_var($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d AND leader_user_id = %d LIMIT 1", $league_id, $uid));
            return (bool) $t;
        },
        'args'                => [
            'id'       => ['required' => true, 'type' => 'integer'],
            'page'     => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'default' => 1],
            'per_page' => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => LUBOWA_API_PER_PAGE_MAX, 'default' => LUBOWA_API_PER_PAGE_DEFAULT],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)/teams', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_team_create',
        'permission_callback' => function ($request) { return lubowa_can_manage_league($request->get_param('id')); },
        'args'                => [
            'id'              => ['required' => true, 'type' => 'integer'],
            'name'            => ['required' => true, 'type' => 'string'],
            'leader_user_id'  => ['required' => false, 'type' => 'integer'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/teams/(?P<id>\d+)', [
        'methods'             => 'PATCH',
        'callback'            => 'lubowa_api_team_update',
        'permission_callback' => function ($request) { return lubowa_can_manage_team($request->get_param('id')); },
        'args'                => [
            'id'              => ['required' => true, 'type' => 'integer'],
            'name'            => ['required' => false, 'type' => 'string'],
            'leader_user_id'  => ['required' => false, 'type' => 'integer'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/teams/(?P<id>\d+)', [
        'methods'             => 'DELETE',
        'callback'            => 'lubowa_api_team_delete',
        'permission_callback' => function ($request) { return lubowa_can_manage_team($request->get_param('id')); },
        'args'                => ['id' => ['required' => true, 'type' => 'integer']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/teams/(?P<id>\d+)/players', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_player_create',
        'permission_callback' => function ($request) { return lubowa_can_manage_team($request->get_param('id')); },
        'args'                => [
            'id'      => ['required' => true, 'type' => 'integer'],
            'name'    => ['required' => true, 'type' => 'string'],
            'goals'   => ['required' => false, 'type' => 'integer', 'default' => 0],
            'user_id' => ['required' => false, 'type' => 'integer', 'default' => null],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/teams/(?P<id>\d+)/players', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_team_players_list',
        'permission_callback' => 'lubowa_api_logged_in_permission',
        'args'                => [
            'id'       => ['required' => true, 'type' => 'integer'],
            'page'     => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'default' => 1],
            'per_page' => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => LUBOWA_API_PER_PAGE_MAX, 'default' => LUBOWA_API_PER_PAGE_DEFAULT],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/me/player', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_me_player',
        'permission_callback' => 'lubowa_api_logged_in_permission',
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/me/league_roles', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_me_league_roles',
        'permission_callback' => 'lubowa_api_logged_in_permission',
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/players/(?P<id>\d+)', [
        'methods'             => 'PATCH',
        'callback'            => 'lubowa_api_player_update',
        'permission_callback' => 'lubowa_api_logged_in_permission',
        'args'                => [
            'id'      => ['required' => true, 'type' => 'integer'],
            'name'    => ['required' => false, 'type' => 'string'],
            'goals'   => ['required' => false, 'type' => 'integer'],
            'user_id' => ['required' => false, 'type' => 'integer'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/players/(?P<id>\d+)', [
        'methods'             => 'DELETE',
        'callback'            => 'lubowa_api_player_delete',
        'permission_callback' => function ($request) {
            global $wpdb;
            $pid = (int) $request->get_param('id');
            $p = $wpdb->get_row($wpdb->prepare("SELECT team_id FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $pid));
            return $p && lubowa_can_manage_team($p->team_id);
        },
        'args'                => ['id' => ['required' => true, 'type' => 'integer']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)/fixtures/generate', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_fixtures_generate',
        'permission_callback' => function ($request) { return lubowa_can_manage_league($request->get_param('id')); },
        'args'                => ['id' => ['required' => true, 'type' => 'integer']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)/fixtures/reset', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_fixtures_reset',
        'permission_callback' => function ($request) { return lubowa_can_manage_league($request->get_param('id')); },
        'args'                => ['id' => ['required' => true, 'type' => 'integer']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/leagues/(?P<id>\d+)/fixtures', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_fixtures_list',
        'permission_callback' => function ($request) { return lubowa_can_manage_league($request->get_param('id')); },
        'args'                => [
            'id'       => ['required' => true, 'type' => 'integer'],
            'page'     => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'default' => 1],
            'per_page' => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => LUBOWA_API_PER_PAGE_MAX, 'default' => LUBOWA_API_PER_PAGE_DEFAULT],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/fixtures/(?P<id>\d+)', [
        'methods'             => 'PATCH',
        'callback'            => 'lubowa_api_fixture_update',
        'permission_callback' => function ($request) {
            global $wpdb;
            $f = $wpdb->get_row($wpdb->prepare("SELECT league_id FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $request->get_param('id')));
            return $f && lubowa_can_manage_league($f->league_id);
        },
        'args'                => [
            'id'                => ['required' => true, 'type' => 'integer'],
            'home_goals'        => ['required' => false, 'type' => 'integer'],
            'away_goals'        => ['required' => false, 'type' => 'integer'],
            'result_confirmed'  => ['required' => false, 'type' => 'integer', 'enum' => [0, 1]],
            'match_date'        => ['required' => false, 'type' => 'string'],
            'match_time'        => ['required' => false, 'type' => 'string'],
            'started_at'        => ['required' => false, 'type' => 'boolean'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/fixtures/(?P<id>\d+)/score', [
        'methods'             => 'DELETE',
        'callback'            => 'lubowa_api_fixture_clear_score',
        'permission_callback' => function ($request) {
            global $wpdb;
            $f = $wpdb->get_row($wpdb->prepare("SELECT league_id FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $request->get_param('id')));
            return $f && lubowa_can_manage_league($f->league_id);
        },
        'args'                => ['id' => ['required' => true, 'type' => 'integer']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/fixtures/(?P<id>\d+)/goals', [
        'methods'             => 'POST',
        'callback'            => 'lubowa_api_fixture_add_goals',
        'permission_callback' => 'lubowa_api_logged_in_permission',
        'args'                => [
            'id'        => ['required' => true, 'type' => 'integer'],
            'player_id' => ['required' => true, 'type' => 'integer'],
            'goals'     => ['required' => true, 'type' => 'integer', 'minimum' => 1],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/fixtures/(?P<fixture_id>\d+)/goals', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_fixture_goals_list',
        'permission_callback' => 'lubowa_api_logged_in_permission',
        'args'                => [
            'fixture_id' => ['required' => true, 'type' => 'integer'],
            'page'       => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'default' => 1],
            'per_page'   => ['required' => false, 'type' => 'integer', 'minimum' => 1, 'maximum' => LUBOWA_API_PER_PAGE_MAX, 'default' => LUBOWA_API_PER_PAGE_DEFAULT],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/fixtures/(?P<fixture_id>\d+)/goals/(?P<goal_id>\d+)', [
        'methods'             => 'PATCH',
        'callback'            => 'lubowa_api_fixture_goal_update',
        'permission_callback' => function ($request) {
            global $wpdb;
            $fixture_id = (int) $request->get_param('fixture_id');
            $goal_id    = (int) $request->get_param('goal_id');
            $goal = $wpdb->get_row($wpdb->prepare("SELECT team_id FROM " . LUBOWA_GOALS_TABLE . " WHERE id = %d AND fixture_id = %d", $goal_id, $fixture_id));
            if (!$goal) {
                return false;
            }
            return lubowa_can_record_goals_for_team_in_fixture($fixture_id, (int) $goal->team_id);
        },
        'args'                => [
            'fixture_id' => ['required' => true, 'type' => 'integer'],
            'goal_id'    => ['required' => true, 'type' => 'integer'],
            'goals'      => ['required' => true, 'type' => 'integer', 'minimum' => 1],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/fixtures/(?P<fixture_id>\d+)/goals/(?P<goal_id>\d+)', [
        'methods'             => 'DELETE',
        'callback'            => 'lubowa_api_fixture_goal_delete',
        'permission_callback' => function ($request) {
            global $wpdb;
            $fixture_id = (int) $request->get_param('fixture_id');
            $goal_id    = (int) $request->get_param('goal_id');
            $goal = $wpdb->get_row($wpdb->prepare("SELECT team_id FROM " . LUBOWA_GOALS_TABLE . " WHERE id = %d AND fixture_id = %d", $goal_id, $fixture_id));
            if (!$goal) {
                return false;
            }
            return lubowa_can_record_goals_for_team_in_fixture($fixture_id, (int) $goal->team_id);
        },
        'args'                => [
            'fixture_id' => ['required' => true, 'type' => 'integer'],
            'goal_id'    => ['required' => true, 'type' => 'integer'],
        ],
    ]);

    register_rest_route(LUBOWA_API_NAMESPACE, '/public/leagues/(?P<code>[a-zA-Z0-9\-]+)', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_league_public',
        'permission_callback' => '__return_true',
        'args'                => ['code' => ['required' => true, 'type' => 'string']],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/public/leagues/(?P<code>[a-zA-Z0-9\-]+)/results', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_league_results_public',
        'permission_callback' => '__return_true',
        'args'                => [
            'code' => ['required' => true, 'type' => 'string'],
            'date' => ['required' => false, 'type' => 'string'],
        ],
    ]);
    register_rest_route(LUBOWA_API_NAMESPACE, '/public/leaderboard', [
        'methods'             => 'GET',
        'callback'            => 'lubowa_api_leaderboard_public',
        'permission_callback' => '__return_true',
    ]);
});

function lubowa_api_booking_create(WP_REST_Request $request) {
    global $wpdb;
    $table = LUBOWA_BOOKINGS_TABLE;
    $service      = trim(sanitize_text_field($request->get_param('service') ?? ''));
    $date         = trim((string) $request->get_param('date'));
    $time_slot    = trim(sanitize_text_field($request->get_param('time_slot')));
    $contact_name = trim(sanitize_text_field($request->get_param('contact_name')));
    $contact_phone = trim(sanitize_text_field($request->get_param('contact_phone')));
    $contact_email = trim(sanitize_email($request->get_param('contact_email')));
    $notes        = sanitize_textarea_field($request->get_param('notes'));

    $wpdb->insert($table, [
        'date'          => $date,
        'time_slot'     => $time_slot,
        'contact_name'  => $contact_name,
        'contact_phone' => $contact_phone,
        'contact_email' => $contact_email,
        'notes'         => $notes,
        'service'       => $service,
        'status'        => 'pending',
    ]);
    if ($wpdb->last_error) {
        $error = $wpdb->last_error;
        if (strpos($error, 'Duplicate entry') !== false && strpos($error, 'unique_slot') !== false) {
            return lubowa_api_error('slot_unavailable', 'This time slot is no longer available. Please choose another time.', 409);
        }
        return lubowa_api_error('create_failed', 'Failed to create booking', 500);
    }
    $id = $wpdb->insert_id;
    return new WP_REST_Response(['id' => (int) $id, 'status' => 'pending'], 201);
}

function lubowa_api_booking_list(WP_REST_Request $request) {
    global $wpdb;
    $email    = sanitize_email($request->get_param('contact_email'));
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = (int) $request->get_param('per_page');
    $per_page = $per_page < 1 ? LUBOWA_API_PER_PAGE_DEFAULT : min($per_page, LUBOWA_API_PER_PAGE_MAX);
    $sort     = $request->get_param('sort') ?: '-created_at';
    $status   = $request->get_param('status');

    $where  = ['contact_email = %s'];
    $params = [$email];
    if ($status !== null && $status !== '') {
        $allowed = ['pending', 'approved', 'canceled', 'rejected'];
        if (in_array($status, $allowed, true)) {
            $where[]  = 'status = %s';
            $params[] = $status;
        }
    }
    $order = ($sort === 'created_at') ? 'ASC' : 'DESC';

    $table     = LUBOWA_BOOKINGS_TABLE;
    $where_sql = implode(' AND ', $where);
    $total     = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $table WHERE $where_sql", ...$params));
    $offset    = ($page - 1) * $per_page;
    $rows      = $wpdb->get_results($wpdb->prepare(
        "SELECT id, date, time_slot, contact_name, service, status, created_at FROM $table WHERE $where_sql ORDER BY created_at $order LIMIT %d OFFSET %d",
        ...array_merge($params, [$per_page, $offset])
    ), ARRAY_A);
    return lubowa_api_paginated($rows ?: [], $page, $per_page, $total);
}

function lubowa_api_booked_slots(WP_REST_Request $request) {
    global $wpdb;

    $date    = trim((string) $request->get_param('date'));
    $service = trim(sanitize_text_field($request->get_param('service')));
    $status  = $request->get_param('status');

    $table = LUBOWA_BOOKINGS_TABLE;

    $where  = ['date = %s', 'service = %s'];
    $params = [$date, $service];

    if ($status !== null && $status !== '') {
        $allowed = ['pending', 'approved', 'canceled', 'rejected'];
        if (in_array($status, $allowed, true)) {
            $where[]  = 'status = %s';
            $params[] = $status;
        }
    }

    $where_sql = implode(' AND ', $where);

    $rows = $wpdb->get_results(
        $wpdb->prepare(
            "SELECT time_slot, status FROM $table WHERE $where_sql ORDER BY time_slot ASC",
            ...$params
        ),
        ARRAY_A
    );

    return new WP_REST_Response($rows ?: [], 200);
}

function lubowa_api_league_code() {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    do {
        $code = '';
        for ($i = 0; $i < 6; $i++) {
            $code .= $chars[wp_rand(0, strlen($chars) - 1)];
        }
        $exists = $GLOBALS['wpdb']->get_var($GLOBALS['wpdb']->prepare(
            "SELECT 1 FROM " . LUBOWA_LEAGUES_TABLE . " WHERE code = %s", $code
        ));
    } while ($exists);
    return $code;
}

function lubowa_api_league_create(WP_REST_Request $request) {
    global $wpdb;
    $name = sanitize_text_field($request->get_param('name'));
    $code = lubowa_api_league_code();
    $created_by = get_current_user_id();
    $legs = (int) ($request->get_param('legs') ?: 1);
    if ($legs < 1 || $legs > 10) {
        $legs = 1;
    }
    $booking_id = $request->has_param('booking_id') ? (int) $request->get_param('booking_id') : null;
    if ($booking_id > 0) {
        $exists = $wpdb->get_var($wpdb->prepare("SELECT id FROM " . LUBOWA_BOOKINGS_TABLE . " WHERE id = %d", $booking_id));
        if (!$exists) {
            return lubowa_api_error('booking_not_found', 'Booking not found', 404);
        }
    } else {
        $booking_id = null;
    }
    $insert = ['name' => $name, 'code' => $code, 'legs' => $legs, 'created_by' => $created_by ?: null];
    if ($booking_id !== null) {
        $insert['booking_id'] = $booking_id;
    }
    $wpdb->insert(LUBOWA_LEAGUES_TABLE, $insert);
    if ($wpdb->last_error) {
        return lubowa_api_error('create_failed', 'Failed to create league', 500);
    }
    $id = $wpdb->insert_id;
    $row = $wpdb->get_row($wpdb->prepare("SELECT id, name, code, legs, booking_id, created_by FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $id), ARRAY_A);
    return new WP_REST_Response($row ?: (object)[], 201);
}

function lubowa_api_league_list(WP_REST_Request $request) {
    global $wpdb;
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = (int) $request->get_param('per_page');
    $per_page = $per_page < 1 ? LUBOWA_API_PER_PAGE_DEFAULT : min($per_page, LUBOWA_API_PER_PAGE_MAX);
    $sort     = $request->get_param('sort') ?: '-created_at';
    $order_col = in_array($sort, ['name', '-name'], true) ? 'name' : 'created_at';
    $order_dir = (strpos($sort, '-') === 0) ? 'DESC' : 'ASC';

    if (current_user_can('manage_options')) {
        $base_sql = "SELECT id, name, code, legs, booking_id, created_by, created_at FROM " . LUBOWA_LEAGUES_TABLE;
        $total    = (int) $wpdb->get_var("SELECT COUNT(*) FROM " . LUBOWA_LEAGUES_TABLE);
        $rows     = $wpdb->get_results($wpdb->prepare(
            "$base_sql ORDER BY $order_col $order_dir LIMIT %d OFFSET %d",
            $per_page,
            ($page - 1) * $per_page
        ), ARRAY_A);
    } else {
        $uid      = get_current_user_id();
        $base_sql = "SELECT l.id, l.name, l.code, l.legs, l.booking_id, l.created_by, l.created_at FROM " . LUBOWA_LEAGUES_TABLE . " l LEFT JOIN " . LUBOWA_TEAMS_TABLE . " t ON t.league_id = l.id WHERE l.created_by = %d OR t.leader_user_id = %d GROUP BY l.id";
        $total    = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM (" . $base_sql . ") x", $uid, $uid));
        $rows     = $wpdb->get_results($wpdb->prepare(
            "$base_sql ORDER BY l.$order_col $order_dir LIMIT %d OFFSET %d",
            $uid,
            $uid,
            $per_page,
            ($page - 1) * $per_page
        ), ARRAY_A);
    }
    return lubowa_api_paginated($rows ?: [], $page, $per_page, $total);
}

function lubowa_api_league_update(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $league = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $id));
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $updates = [];
    if ($request->has_param('name')) {
        $updates['name'] = sanitize_text_field($request->get_param('name'));
    }
    if ($request->has_param('code')) {
        $code = sanitize_text_field($request->get_param('code'));
        if ($code !== '') {
            $exists = $wpdb->get_var($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE code = %s AND id != %d", $code, $id));
            if ($exists) {
                return lubowa_api_error('code_already_in_use', 'Code already in use', 400);
            }
            $updates['code'] = $code;
        }
    }
    if ($request->has_param('legs')) {
        $legs = (int) $request->get_param('legs');
        if ($legs >= 1 && $legs <= 10) {
            $updates['legs'] = $legs;
        }
    }
    if ($request->has_param('booking_id')) {
        $bid = (int) $request->get_param('booking_id');
        if ($bid <= 0) {
            $updates['booking_id'] = null;
        } else {
            $exists = $wpdb->get_var($wpdb->prepare("SELECT id FROM " . LUBOWA_BOOKINGS_TABLE . " WHERE id = %d", $bid));
            if ($exists) {
                $updates['booking_id'] = $bid;
            }
        }
    }
    if (empty($updates)) {
        return lubowa_api_error('validation_error', 'Provide name, code, legs, or booking_id', 400);
    }
    $wpdb->update(LUBOWA_LEAGUES_TABLE, $updates, ['id' => $id]);
    if ($wpdb->last_error) {
        return lubowa_api_error('update_failed', 'Update failed', 500);
    }
    $row = $wpdb->get_row($wpdb->prepare("SELECT id, name, code, legs, booking_id, created_at FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $id), ARRAY_A);
    return new WP_REST_Response($row ?: (object)[], 200);
}

function lubowa_api_league_delete(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $league = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $id));
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $team_ids = $wpdb->get_col($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d", $id));
    foreach ($team_ids as $tid) {
        $wpdb->delete(LUBOWA_PLAYERS_TABLE, ['team_id' => $tid]);
    }
    $wpdb->delete(LUBOWA_TEAMS_TABLE, ['league_id' => $id]);
    $wpdb->delete(LUBOWA_FIXTURES_TABLE, ['league_id' => $id]);
    $wpdb->delete(LUBOWA_LEAGUES_TABLE, ['id' => $id]);
    return new WP_REST_Response(['message' => 'League deleted'], 200);
}

function lubowa_api_league_teams_list(WP_REST_Request $request) {
    global $wpdb;
    $league_id = (int) $request->get_param('id');
    $league    = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id));
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = (int) $request->get_param('per_page');
    $per_page = $per_page < 1 ? LUBOWA_API_PER_PAGE_DEFAULT : min($per_page, LUBOWA_API_PER_PAGE_MAX);
    $total    = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d", $league_id));
    $offset   = ($page - 1) * $per_page;
    $teams    = $wpdb->get_results($wpdb->prepare(
        "SELECT id, name, leader_user_id FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d ORDER BY name LIMIT %d OFFSET %d",
        $league_id,
        $per_page,
        $offset
    ), ARRAY_A);
    return lubowa_api_paginated($teams ?: [], $page, $per_page, $total);
}

function lubowa_api_team_create(WP_REST_Request $request) {
    global $wpdb;
    $league_id = (int) $request->get_param('id');
    $name      = sanitize_text_field($request->get_param('name'));
    $league    = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id));
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $leader_user_id = $request->has_param('leader_user_id') ? (int) $request->get_param('leader_user_id') : null;
    $data = ['league_id' => $league_id, 'name' => $name];
    if ($leader_user_id > 0) {
        $data['leader_user_id'] = $leader_user_id;
    }
    $wpdb->insert(LUBOWA_TEAMS_TABLE, $data);
    if ($wpdb->last_error) {
        return lubowa_api_error('team_name_exists', 'Team name may already exist in this league', 400);
    }
    return new WP_REST_Response(['id' => (int) $wpdb->insert_id, 'name' => $name], 201);
}

function lubowa_api_team_update(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $team = $wpdb->get_row($wpdb->prepare("SELECT id, league_id FROM " . LUBOWA_TEAMS_TABLE . " WHERE id = %d", $id));
    if (!$team) {
        return lubowa_api_error('team_not_found', 'Team not found', 404);
    }
    $updates = [];
    if ($request->has_param('name')) {
        $name = sanitize_text_field($request->get_param('name'));
        $exists = $wpdb->get_var($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d AND name = %s AND id != %d", $team->league_id, $name, $id));
        if ($exists) {
            return lubowa_api_error('team_name_exists', 'Team name already exists in this league', 400);
        }
        $updates['name'] = $name;
    }
    if ($request->has_param('leader_user_id')) {
        $updates['leader_user_id'] = (int) $request->get_param('leader_user_id') ?: null;
    }
    if (empty($updates)) {
        return lubowa_api_error('validation_error', 'Provide name and/or leader_user_id', 400);
    }
    $wpdb->update(LUBOWA_TEAMS_TABLE, $updates, ['id' => $id]);
    if ($wpdb->last_error) {
        return lubowa_api_error('update_failed', 'Update failed', 500);
    }
    $row = $wpdb->get_row($wpdb->prepare("SELECT id, league_id, name FROM " . LUBOWA_TEAMS_TABLE . " WHERE id = %d", $id), ARRAY_A);
    return new WP_REST_Response($row ?: (object)[], 200);
}

function lubowa_api_team_delete(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $team = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE id = %d", $id));
    if (!$team) {
        return lubowa_api_error('team_not_found', 'Team not found', 404);
    }
    $wpdb->delete(LUBOWA_PLAYERS_TABLE, ['team_id' => $id]);
    $wpdb->delete(LUBOWA_FIXTURES_TABLE, ['home_team_id' => $id]);
    $wpdb->delete(LUBOWA_FIXTURES_TABLE, ['away_team_id' => $id]);
    $wpdb->delete(LUBOWA_TEAMS_TABLE, ['id' => $id]);
    return new WP_REST_Response(['message' => 'Team deleted'], 200);
}

function lubowa_api_player_create(WP_REST_Request $request) {
    global $wpdb;
    $team_id = (int) $request->get_param('id');
    $name    = sanitize_text_field($request->get_param('name'));
    $goals   = (int) $request->get_param('goals');
    $user_id = $request->has_param('user_id') ? (int) $request->get_param('user_id') : null;
    $team    = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE id = %d", $team_id));
    if (!$team) {
        return lubowa_api_error('team_not_found', 'Team not found', 404);
    }
    $count = $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM " . LUBOWA_PLAYERS_TABLE . " WHERE team_id = %d", $team_id));
    if ($count >= 8) {
        return lubowa_api_error('player_limit_reached', 'Maximum 8 players per team (5 + 3 subs)', 400);
    }
    $data = ['team_id' => $team_id, 'name' => $name, 'goals' => $goals];
    if ($user_id > 0) {
        $data['user_id'] = $user_id;
    }
    $wpdb->insert(LUBOWA_PLAYERS_TABLE, $data);
    if ($wpdb->last_error) {
        return lubowa_api_error('create_failed', 'Failed to add player', 500);
    }
    return new WP_REST_Response(['id' => (int) $wpdb->insert_id, 'name' => $name, 'goals' => $goals], 201);
}

function lubowa_api_team_players_list(WP_REST_Request $request) {
    global $wpdb;
    $team_id  = (int) $request->get_param('id');
    $team     = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE id = %d", $team_id));
    if (!$team) {
        return lubowa_api_error('team_not_found', 'Team not found', 404);
    }
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = (int) $request->get_param('per_page');
    $per_page = $per_page < 1 ? LUBOWA_API_PER_PAGE_DEFAULT : min($per_page, LUBOWA_API_PER_PAGE_MAX);
    $total    = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM " . LUBOWA_PLAYERS_TABLE . " WHERE team_id = %d", $team_id));
    $offset   = ($page - 1) * $per_page;
    $rows     = $wpdb->get_results($wpdb->prepare(
        "SELECT id, name, goals FROM " . LUBOWA_PLAYERS_TABLE . " WHERE team_id = %d ORDER BY name LIMIT %d OFFSET %d",
        $team_id,
        $per_page,
        $offset
    ), ARRAY_A);
    return lubowa_api_paginated($rows ?: [], $page, $per_page, $total);
}

function lubowa_api_player_update(WP_REST_Request $request) {
    global $wpdb;
    $player_id = (int) $request->get_param('id');
    $player = $wpdb->get_row($wpdb->prepare("SELECT id, user_id, team_id FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $player_id), ARRAY_A);
    if (!$player) {
        return lubowa_api_error('player_not_found', 'Player not found', 404);
    }
    $current_user = get_current_user_id();
    if (!$current_user) {
        return lubowa_api_error('unauthorized', 'Not logged in', 401);
    }
    $can_manage_team = lubowa_can_manage_team((int) $player['team_id']);
    $updates = [];
    if (current_user_can('manage_options') || $can_manage_team) {
        if ($request->has_param('name')) {
            $updates['name'] = sanitize_text_field($request->get_param('name'));
        }
        if ($request->has_param('goals')) {
            $updates['goals'] = (int) $request->get_param('goals');
        }
    }
    if ($request->has_param('user_id')) {
        $user_id = (int) $request->get_param('user_id');
        if (!current_user_can('manage_options') && $user_id !== $current_user) {
            return lubowa_api_error('forbidden', 'Can only link to your own account', 403);
        }
        $updates['user_id'] = $user_id ?: null;
    }
    if (empty($updates)) {
        return lubowa_api_error('validation_error', 'Provide name, goals, and/or user_id', 400);
    }
    $wpdb->update(LUBOWA_PLAYERS_TABLE, $updates, ['id' => $player_id]);
    if ($wpdb->last_error) {
        return lubowa_api_error('update_failed', 'Update failed', 500);
    }
    $row = $wpdb->get_row($wpdb->prepare("SELECT id, name, team_id, goals, user_id FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $player_id), ARRAY_A);
    return new WP_REST_Response($row ?: (object)[], 200);
}

function lubowa_api_player_delete(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $player = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $id));
    if (!$player) {
        return lubowa_api_error('player_not_found', 'Player not found', 404);
    }
    $wpdb->delete(LUBOWA_PLAYERS_TABLE, ['id' => $id]);
    return new WP_REST_Response(['message' => 'Player deleted'], 200);
}

function lubowa_api_me_player(WP_REST_Request $request) {
    global $wpdb;
    $user_id = get_current_user_id();
    if (!$user_id) {
        return lubowa_api_error('unauthorized', 'Not logged in', 401);
    }
    $player = $wpdb->get_row($wpdb->prepare(
        "SELECT p.id, p.name, p.team_id, p.goals, t.name AS team_name, t.league_id, l.name AS league_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id JOIN " . LUBOWA_LEAGUES_TABLE . " l ON t.league_id = l.id WHERE p.user_id = %d LIMIT 1",
        $user_id
    ), ARRAY_A);
    if (!$player) {
        return lubowa_api_error('player_not_found', 'No player linked to this account', 404);
    }
    return new WP_REST_Response($player, 200);
}

function lubowa_api_me_league_roles(WP_REST_Request $request) {
    global $wpdb;
    $uid = get_current_user_id();
    if (!$uid) {
        return lubowa_api_error('unauthorized', 'Not logged in', 401);
    }
    $managed = $wpdb->get_col($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE created_by = %d ORDER BY id", $uid));
    $led = $wpdb->get_col($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE leader_user_id = %d ORDER BY id", $uid));
    return new WP_REST_Response([
        'can_create_league'   => lubowa_can_create_league(),
        'managed_league_ids'  => array_map('intval', $managed ?: []),
        'led_team_ids'       => array_map('intval', $led ?: []),
    ], 200);
}

function lubowa_api_fixtures_generate(WP_REST_Request $request) {
    global $wpdb;
    $league_id = (int) $request->get_param('id');
    $league = $wpdb->get_row($wpdb->prepare("SELECT legs FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id), ARRAY_A);
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $teams = $wpdb->get_col($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d ORDER BY id", $league_id));
    if (count($teams) < 2) {
        return lubowa_api_error('validation_error', 'A league must have at least 2 teams to generate fixtures', 400);
    }
    $legs = isset($league['legs']) ? max(1, min(10, (int) $league['legs'])) : 1;
    $wpdb->delete(LUBOWA_FIXTURES_TABLE, ['league_id' => $league_id]);
    $order = 0;
    $match_date = current_time('Y-m-d');
    // 1 leg = one fixture per pair (A vs B). 2 legs = two fixtures (A vs B, B vs A). Pairs (i,j) with i < j only; each pair gets `legs` fixtures, alternating home/away.
    for ($i = 0; $i < count($teams); $i++) {
        for ($j = $i + 1; $j < count($teams); $j++) {
            for ($leg = 0; $leg < $legs; $leg++) {
                $home = ($leg % 2 === 0) ? $teams[$i] : $teams[$j];
                $away = ($leg % 2 === 0) ? $teams[$j] : $teams[$i];
                $wpdb->insert(LUBOWA_FIXTURES_TABLE, [
                    'league_id'       => $league_id,
                    'home_team_id'    => $home,
                    'away_team_id'    => $away,
                    'home_goals'      => null,
                    'away_goals'      => null,
                    'result_confirmed'=> 0,
                    'match_date'      => $match_date,
                    'sort_order'      => $order++,
                ]);
            }
        }
    }
    $fixtures = $wpdb->get_results($wpdb->prepare(
        "SELECT f.id, f.home_team_id, f.away_team_id, f.home_goals, f.away_goals, ht.name AS home_team_name, at.name AS away_team_name FROM " . LUBOWA_FIXTURES_TABLE . " f JOIN " . LUBOWA_TEAMS_TABLE . " ht ON f.home_team_id = ht.id JOIN " . LUBOWA_TEAMS_TABLE . " at ON f.away_team_id = at.id WHERE f.league_id = %d ORDER BY f.sort_order",
        $league_id
    ), ARRAY_A);
    return new WP_REST_Response($fixtures ?: [], 200);
}

function lubowa_api_fixtures_reset(WP_REST_Request $request) {
    global $wpdb;
    $league_id = (int) $request->get_param('id');
    $wpdb->delete(LUBOWA_FIXTURES_TABLE, ['league_id' => $league_id]);
    return new WP_REST_Response(['message' => 'Fixtures reset'], 200);
}

function lubowa_api_fixtures_list(WP_REST_Request $request) {
    global $wpdb;
    $league_id = (int) $request->get_param('id');
    $league = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id));
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = (int) $request->get_param('per_page');
    $per_page = $per_page < 1 ? LUBOWA_API_PER_PAGE_DEFAULT : min($per_page, LUBOWA_API_PER_PAGE_MAX);
    $total    = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM " . LUBOWA_FIXTURES_TABLE . " WHERE league_id = %d", $league_id));
    $offset   = ($page - 1) * $per_page;
    $rows     = $wpdb->get_results($wpdb->prepare(
        "SELECT f.id, f.home_team_id, f.away_team_id, f.home_goals, f.away_goals, f.result_confirmed, f.match_date, f.match_time, f.started_at, f.sort_order, ht.name AS home_team_name, at.name AS away_team_name
         FROM " . LUBOWA_FIXTURES_TABLE . " f
         JOIN " . LUBOWA_TEAMS_TABLE . " ht ON f.home_team_id = ht.id
         JOIN " . LUBOWA_TEAMS_TABLE . " at ON f.away_team_id = at.id
         WHERE f.league_id = %d
         ORDER BY f.sort_order ASC, f.id ASC
         LIMIT %d OFFSET %d",
        $league_id,
        $per_page,
        $offset
    ), ARRAY_A);
    return lubowa_api_paginated($rows ?: [], $page, $per_page, $total);
}

function lubowa_api_fixture_update(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $current = $wpdb->get_row($wpdb->prepare("SELECT result_confirmed FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $id), ARRAY_A);
    if (!$current) {
        return lubowa_api_error('fixture_not_found', 'Fixture not found', 404);
    }
    if (!empty($current['result_confirmed'])) {
        if ($request->has_param('home_goals') || $request->has_param('away_goals') || ($request->has_param('result_confirmed') && !(int) $request->get_param('result_confirmed'))) {
            return lubowa_api_error('result_confirmed', 'Result is confirmed; cannot change score or unconfirm', 400);
        }
    }
    $updates = [];
    if ($request->has_param('home_goals')) {
        $updates['home_goals'] = (int) $request->get_param('home_goals');
    }
    if ($request->has_param('away_goals')) {
        $updates['away_goals'] = (int) $request->get_param('away_goals');
    }
    if ($request->has_param('result_confirmed')) {
        $updates['result_confirmed'] = (int) $request->get_param('result_confirmed') ? 1 : 0;
        if ($updates['result_confirmed'] === 1) {
            $f = $wpdb->get_row($wpdb->prepare("SELECT home_goals, away_goals FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $id));
            if (!$f || $f->home_goals === null || $f->away_goals === null) {
                return lubowa_api_error('validation_error', 'Set home_goals and away_goals before confirming full time', 400);
            }
        }
    }
    if ($request->has_param('match_date')) {
        $d = sanitize_text_field($request->get_param('match_date'));
        $updates['match_date'] = preg_match('/^\d{4}-\d{2}-\d{2}$/', $d) ? $d : null;
    }
    if ($request->has_param('match_time')) {
        $updates['match_time'] = sanitize_text_field($request->get_param('match_time')) ?: null;
    }
    if ($request->has_param('started_at')) {
        $updates['started_at'] = $request->get_param('started_at') ? current_time('mysql') : null;
    }
    if (empty($updates)) {
        return lubowa_api_error('validation_error', 'Provide home_goals, away_goals, result_confirmed, match_date, match_time, or started_at', 400);
    }
    $wpdb->update(LUBOWA_FIXTURES_TABLE, $updates, ['id' => $id]);
    if ($wpdb->last_error) {
        return lubowa_api_error('update_failed', 'Update failed', 500);
    }
    $row = $wpdb->get_row($wpdb->prepare("SELECT id, home_team_id, away_team_id, home_goals, away_goals, result_confirmed, match_date, match_time, started_at FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $id), ARRAY_A);
    return new WP_REST_Response($row ?: (object)[], 200);
}

function lubowa_api_fixture_clear_score(WP_REST_Request $request) {
    global $wpdb;
    $id = (int) $request->get_param('id');
    $fixture = $wpdb->get_row($wpdb->prepare("SELECT id, result_confirmed FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $id), ARRAY_A);
    if (!$fixture) {
        return lubowa_api_error('fixture_not_found', 'Fixture not found', 404);
    }
    if (!empty($fixture['result_confirmed'])) {
        return lubowa_api_error('result_confirmed', 'Result is confirmed; cannot clear score', 400);
    }
    $wpdb->update(LUBOWA_FIXTURES_TABLE, ['home_goals' => null, 'away_goals' => null, 'result_confirmed' => 0], ['id' => $id]);
    $row = $wpdb->get_row($wpdb->prepare("SELECT id, home_team_id, away_team_id, home_goals, away_goals, result_confirmed FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $id), ARRAY_A);
    return new WP_REST_Response($row ?: (object)[], 200);
}

function lubowa_api_fixture_add_goals(WP_REST_Request $request) {
    global $wpdb;
    $fixture_id = (int) $request->get_param('id');
    $player_id  = (int) $request->get_param('player_id');
    $goals      = (int) $request->get_param('goals');
    if ($goals < 1) {
        return lubowa_api_error('validation_error', 'goals must be at least 1', 400);
    }
    $fixture = $wpdb->get_row($wpdb->prepare("SELECT id, home_team_id, away_team_id, home_goals, away_goals, started_at, result_confirmed FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $fixture_id), ARRAY_A);
    if (!$fixture) {
        return lubowa_api_error('fixture_not_found', 'Fixture not found', 404);
    }
    if (!empty($fixture['result_confirmed'])) {
        return lubowa_api_error('match_full_time', 'Match is full time; cannot add goals', 400);
    }
    if (empty($fixture['started_at'])) {
        return lubowa_api_error('match_not_started', 'Start the match before recording goals', 400);
    }
    $player = $wpdb->get_row($wpdb->prepare("SELECT id, team_id, goals FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $player_id), ARRAY_A);
    if (!$player) {
        return lubowa_api_error('player_not_found', 'Player not found', 404);
    }
    $home_id = (int) $fixture['home_team_id'];
    $away_id = (int) $fixture['away_team_id'];
    $team_id = (int) $player['team_id'];
    if ($team_id !== $home_id && $team_id !== $away_id) {
        return lubowa_api_error('validation_error', 'Player is not in this fixture', 400);
    }
    if (!lubowa_can_record_goals_for_team_in_fixture($fixture_id, $team_id)) {
        return lubowa_api_error('forbidden', 'You cannot record goals for this team', 403);
    }
    // Increment aggregates.
    $wpdb->query($wpdb->prepare("UPDATE " . LUBOWA_PLAYERS_TABLE . " SET goals = goals + %d WHERE id = %d", $goals, $player_id));
    if ($team_id === $home_id) {
        $new_home = (int) $fixture['home_goals'] + $goals;
        $wpdb->update(LUBOWA_FIXTURES_TABLE, ['home_goals' => $new_home], ['id' => $fixture_id]);
    } else {
        $new_away = (int) $fixture['away_goals'] + $goals;
        $wpdb->update(LUBOWA_FIXTURES_TABLE, ['away_goals' => $new_away], ['id' => $fixture_id]);
    }
    // Log individual goal operation so it can be patched/deleted later.
    $wpdb->insert(LUBOWA_GOALS_TABLE, [
        'fixture_id' => $fixture_id,
        'team_id'    => $team_id,
        'player_id'  => $player_id,
        'goals'      => $goals,
    ]);
    $goal_id = $wpdb->insert_id;
    $updated = $wpdb->get_row($wpdb->prepare("SELECT id, name, goals FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $player_id), ARRAY_A);
    $goal    = $wpdb->get_row($wpdb->prepare("SELECT id, fixture_id, team_id, player_id, goals, created_at FROM " . LUBOWA_GOALS_TABLE . " WHERE id = %d", $goal_id), ARRAY_A);
    return new WP_REST_Response(['player' => $updated, 'goal' => $goal, 'message' => 'Goals added'], 200);
}

/**
 * List logged goal operations for a fixture.
 */
function lubowa_api_fixture_goals_list(WP_REST_Request $request) {
    global $wpdb;
    $fixture_id = (int) $request->get_param('fixture_id');
    $fixture    = $wpdb->get_row($wpdb->prepare("SELECT id FROM " . LUBOWA_FIXTURES_TABLE . " WHERE id = %d", $fixture_id));
    if (!$fixture) {
        return lubowa_api_error('fixture_not_found', 'Fixture not found', 404);
    }
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = (int) $request->get_param('per_page');
    $per_page = $per_page < 1 ? LUBOWA_API_PER_PAGE_DEFAULT : min($per_page, LUBOWA_API_PER_PAGE_MAX);
    $total    = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM " . LUBOWA_GOALS_TABLE . " WHERE fixture_id = %d", $fixture_id));
    $offset   = ($page - 1) * $per_page;
    $rows     = $wpdb->get_results($wpdb->prepare(
        "SELECT id, fixture_id, team_id, player_id, goals, created_at FROM " . LUBOWA_GOALS_TABLE . " WHERE fixture_id = %d ORDER BY id ASC LIMIT %d OFFSET %d",
        $fixture_id,
        $per_page,
        $offset
    ), ARRAY_A);
    return lubowa_api_paginated($rows ?: [], $page, $per_page, $total);
}

/**
 * Update a single goal operation (adjusts aggregates by delta).
 */
function lubowa_api_fixture_goal_update(WP_REST_Request $request) {
    global $wpdb;
    $fixture_id = (int) $request->get_param('fixture_id');
    $goal_id    = (int) $request->get_param('goal_id');
    $new_goals  = (int) $request->get_param('goals');
    if ($new_goals < 1) {
        return lubowa_api_error('validation_error', 'goals must be at least 1', 400);
    }
    $goal = $wpdb->get_row($wpdb->prepare(
        "SELECT g.id, g.fixture_id, g.team_id, g.player_id, g.goals, f.home_team_id, f.away_team_id, f.home_goals, f.away_goals, f.started_at, f.result_confirmed
         FROM " . LUBOWA_GOALS_TABLE . " g
         JOIN " . LUBOWA_FIXTURES_TABLE . " f ON g.fixture_id = f.id
         WHERE g.id = %d AND g.fixture_id = %d",
        $goal_id,
        $fixture_id
    ), ARRAY_A);
    if (!$goal) {
        return lubowa_api_error('goal_not_found', 'Goal not found', 404);
    }
    if (!empty($goal['result_confirmed'])) {
        return lubowa_api_error('match_full_time', 'Match is full time; cannot edit goals', 400);
    }
    if (empty($goal['started_at'])) {
        return lubowa_api_error('match_not_started', 'Start the match before editing goals', 400);
    }
    $old_goals = (int) $goal['goals'];
    if ($old_goals === $new_goals) {
        $goal_row = $wpdb->get_row($wpdb->prepare("SELECT id, fixture_id, team_id, player_id, goals, created_at FROM " . LUBOWA_GOALS_TABLE . " WHERE id = %d", $goal_id), ARRAY_A);
        return new WP_REST_Response($goal_row ?: (object)[], 200);
    }
    $delta    = $new_goals - $old_goals;
    $team_id  = (int) $goal['team_id'];
    $player_id = (int) $goal['player_id'];
    $home_id  = (int) $goal['home_team_id'];
    $away_id  = (int) $goal['away_team_id'];

    // Prevent negative aggregates.
    $player = $wpdb->get_row($wpdb->prepare("SELECT goals FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $player_id));
    if (!$player) {
        return lubowa_api_error('player_not_found', 'Player not found', 404);
    }
    $player_goals = (int) $player->goals + $delta;
    if ($player_goals < 0) {
        return lubowa_api_error('validation_error', 'Cannot reduce player goals below zero', 400);
    }
    $home_goals = (int) $goal['home_goals'];
    $away_goals = (int) $goal['away_goals'];
    if ($team_id === $home_id) {
        $home_goals += $delta;
    } else {
        $away_goals += $delta;
    }
    if ($home_goals < 0 || $away_goals < 0) {
        return lubowa_api_error('validation_error', 'Cannot reduce fixture goals below zero', 400);
    }

    // Apply updates.
    $wpdb->update(LUBOWA_GOALS_TABLE, ['goals' => $new_goals], ['id' => $goal_id]);
    $wpdb->update(LUBOWA_PLAYERS_TABLE, ['goals' => $player_goals], ['id' => $player_id]);
    $wpdb->update(LUBOWA_FIXTURES_TABLE, ['home_goals' => $home_goals, 'away_goals' => $away_goals], ['id' => $fixture_id]);

    $goal_row = $wpdb->get_row($wpdb->prepare("SELECT id, fixture_id, team_id, player_id, goals, created_at FROM " . LUBOWA_GOALS_TABLE . " WHERE id = %d", $goal_id), ARRAY_A);
    return new WP_REST_Response($goal_row ?: (object)[], 200);
}

/**
 * Delete a single goal operation (reverses aggregates).
 */
function lubowa_api_fixture_goal_delete(WP_REST_Request $request) {
    global $wpdb;
    $fixture_id = (int) $request->get_param('fixture_id');
    $goal_id    = (int) $request->get_param('goal_id');
    $goal = $wpdb->get_row($wpdb->prepare(
        "SELECT g.id, g.fixture_id, g.team_id, g.player_id, g.goals, f.home_team_id, f.away_team_id, f.home_goals, f.away_goals, f.started_at, f.result_confirmed
         FROM " . LUBOWA_GOALS_TABLE . " g
         JOIN " . LUBOWA_FIXTURES_TABLE . " f ON g.fixture_id = f.id
         WHERE g.id = %d AND g.fixture_id = %d",
        $goal_id,
        $fixture_id
    ), ARRAY_A);
    if (!$goal) {
        return lubowa_api_error('goal_not_found', 'Goal not found', 404);
    }
    if (!empty($goal['result_confirmed'])) {
        return lubowa_api_error('match_full_time', 'Match is full time; cannot delete goals', 400);
    }
    if (empty($goal['started_at'])) {
        return lubowa_api_error('match_not_started', 'Start the match before deleting goals', 400);
    }
    $delta     = -(int) $goal['goals'];
    $team_id   = (int) $goal['team_id'];
    $player_id = (int) $goal['player_id'];
    $home_id   = (int) $goal['home_team_id'];
    $away_id   = (int) $goal['away_team_id'];

    $player = $wpdb->get_row($wpdb->prepare("SELECT goals FROM " . LUBOWA_PLAYERS_TABLE . " WHERE id = %d", $player_id));
    if (!$player) {
        return lubowa_api_error('player_not_found', 'Player not found', 404);
    }
    $player_goals = (int) $player->goals + $delta;
    if ($player_goals < 0) {
        return lubowa_api_error('validation_error', 'Cannot reduce player goals below zero', 400);
    }
    $home_goals = (int) $goal['home_goals'];
    $away_goals = (int) $goal['away_goals'];
    if ($team_id === $home_id) {
        $home_goals += $delta;
    } else {
        $away_goals += $delta;
    }
    if ($home_goals < 0 || $away_goals < 0) {
        return lubowa_api_error('validation_error', 'Cannot reduce fixture goals below zero', 400);
    }

    // Apply updates then delete log entry.
    $wpdb->update(LUBOWA_PLAYERS_TABLE, ['goals' => $player_goals], ['id' => $player_id]);
    $wpdb->update(LUBOWA_FIXTURES_TABLE, ['home_goals' => $home_goals, 'away_goals' => $away_goals], ['id' => $fixture_id]);
    $wpdb->delete(LUBOWA_GOALS_TABLE, ['id' => $goal_id]);

    return new WP_REST_Response(['message' => 'Goal entry deleted'], 200);
}

/**
 * Build league standings (points, wins, draws, losses, goals_for, goals_against) from confirmed fixtures only.
 */
function lubowa_get_league_standings($league_id) {
    global $wpdb;
    $teams = $wpdb->get_results($wpdb->prepare("SELECT id, name FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d ORDER BY name", $league_id), ARRAY_A);
    if (empty($teams)) {
        return [];
    }
    $confirmed = $wpdb->get_results($wpdb->prepare(
        "SELECT home_team_id, away_team_id, home_goals, away_goals FROM " . LUBOWA_FIXTURES_TABLE . " WHERE league_id = %d AND result_confirmed = 1 AND home_goals IS NOT NULL AND away_goals IS NOT NULL",
        $league_id
    ), ARRAY_A);
    $stats = [];
    foreach ($teams as $t) {
        $stats[(int) $t['id']] = ['id' => (int) $t['id'], 'name' => $t['name'], 'points' => 0, 'played' => 0, 'won' => 0, 'drawn' => 0, 'lost' => 0, 'goals_for' => 0, 'goals_against' => 0];
    }
    foreach ($confirmed as $f) {
        $hid = (int) $f['home_team_id'];
        $aid = (int) $f['away_team_id'];
        $hg = (int) $f['home_goals'];
        $ag = (int) $f['away_goals'];
        if (!isset($stats[$hid]) || !isset($stats[$aid])) {
            continue;
        }
        $stats[$hid]['played']++;
        $stats[$aid]['played']++;
        $stats[$hid]['goals_for'] += $hg;
        $stats[$hid]['goals_against'] += $ag;
        $stats[$aid]['goals_for'] += $ag;
        $stats[$aid]['goals_against'] += $hg;
        if ($hg > $ag) {
            $stats[$hid]['points'] += 3;
            $stats[$hid]['won']++;
            $stats[$aid]['lost']++;
        } elseif ($hg < $ag) {
            $stats[$aid]['points'] += 3;
            $stats[$aid]['won']++;
            $stats[$hid]['lost']++;
        } else {
            $stats[$hid]['points']++;
            $stats[$aid]['points']++;
            $stats[$hid]['drawn']++;
            $stats[$aid]['drawn']++;
        }
    }
    usort($stats, function ($a, $b) {
        if ($a['points'] !== $b['points']) {
            return $b['points'] - $a['points'];
        }
        $gd_a = $a['goals_for'] - $a['goals_against'];
        $gd_b = $b['goals_for'] - $b['goals_against'];
        if ($gd_a !== $gd_b) {
            return $gd_b - $gd_a;
        }
        return $b['goals_for'] - $a['goals_for'];
    });
    return $stats;
}

function lubowa_api_league_public(WP_REST_Request $request) {
    global $wpdb;
    $code = sanitize_text_field($request->get_param('code'));
    $league = $wpdb->get_row($wpdb->prepare("SELECT id, name, code, legs FROM " . LUBOWA_LEAGUES_TABLE . " WHERE code = %s", $code), ARRAY_A);
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $league_id = $league['id'];
    $standings = lubowa_get_league_standings($league_id);
    $fixtures = $wpdb->get_results($wpdb->prepare(
        "SELECT f.id, ht.name AS home_team_name, at.name AS away_team_name, f.home_goals, f.away_goals, f.result_confirmed, f.match_date, f.match_time, f.started_at FROM " . LUBOWA_FIXTURES_TABLE . " f JOIN " . LUBOWA_TEAMS_TABLE . " ht ON f.home_team_id = ht.id JOIN " . LUBOWA_TEAMS_TABLE . " at ON f.away_team_id = at.id WHERE f.league_id = %d ORDER BY f.match_date ASC, f.sort_order",
        $league_id
    ), ARRAY_A);
    $top_scorers = $wpdb->get_results($wpdb->prepare(
        "SELECT p.id, p.name, p.goals, t.name AS team_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id WHERE t.league_id = %d AND p.goals > 0 ORDER BY p.goals DESC, p.name ASC LIMIT 50",
        $league_id
    ), ARRAY_A);
    return new WP_REST_Response([
        'league'       => $league,
        'standings'   => $standings,
        'fixtures'    => $fixtures ?: [],
        'top_scorers' => $top_scorers ?: [],
    ], 200);
}

function lubowa_api_league_results_public(WP_REST_Request $request) {
    global $wpdb;
    $code = sanitize_text_field($request->get_param('code'));
    $league = $wpdb->get_row($wpdb->prepare("SELECT id, name, code, legs FROM " . LUBOWA_LEAGUES_TABLE . " WHERE code = %s", $code), ARRAY_A);
    if (!$league) {
        return lubowa_api_error('league_not_found', 'League not found', 404);
    }
    $date = $request->get_param('date');
    if ($date && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        $match_date = $date;
    } else {
        $match_date = current_time('Y-m-d');
    }
    $results = $wpdb->get_results($wpdb->prepare(
        "SELECT f.id, ht.name AS home_team_name, at.name AS away_team_name, f.home_goals, f.away_goals, f.match_date, f.match_time FROM " . LUBOWA_FIXTURES_TABLE . " f JOIN " . LUBOWA_TEAMS_TABLE . " ht ON f.home_team_id = ht.id JOIN " . LUBOWA_TEAMS_TABLE . " at ON f.away_team_id = at.id WHERE f.league_id = %d AND f.match_date = %s AND f.result_confirmed = 1 AND f.home_goals IS NOT NULL AND f.away_goals IS NOT NULL ORDER BY f.match_time ASC, f.sort_order",
        $league['id'],
        $match_date
    ), ARRAY_A);
    return new WP_REST_Response([
        'league' => $league,
        'date'   => $match_date,
        'results' => $results ?: [],
    ], 200);
}

function lubowa_api_leaderboard_public(WP_REST_Request $request) {
    global $wpdb;
    $leagues = $wpdb->get_results("SELECT id, name, code FROM " . LUBOWA_LEAGUES_TABLE . " ORDER BY name", ARRAY_A);
    $out = ['leagues' => []];
    foreach ($leagues as $l) {
        $standings = lubowa_get_league_standings($l['id']);
        $top_scorers = $wpdb->get_results($wpdb->prepare(
            "SELECT p.id, p.name, p.goals, t.name AS team_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id WHERE t.league_id = %d AND p.goals > 0 ORDER BY p.goals DESC, p.name ASC LIMIT 10",
            $l['id']
        ), ARRAY_A);
        $out['leagues'][] = [
            'id'           => (int) $l['id'],
            'name'         => $l['name'],
            'code'         => $l['code'],
            'standings'    => $standings,
            'top_scorers'  => $top_scorers ?: [],
        ];
    }
    $out['top_scorers_all'] = $wpdb->get_results(
        "SELECT p.id, p.name, p.goals, t.name AS team_name, l.name AS league_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id JOIN " . LUBOWA_LEAGUES_TABLE . " l ON t.league_id = l.id WHERE p.goals > 0 ORDER BY p.goals DESC, p.name ASC LIMIT 20",
        ARRAY_A
    );
    return new WP_REST_Response($out, 200);
}

// --- Admin: Lubowa parent menu + App Bookings + Leagues ---
add_action('admin_menu', function () {
    add_menu_page(
        'Lubowa',
        'Lubowa',
        'manage_options',
        'lubowa',
        'lubowa_admin_bookings_page',
        'dashicons-calendar-alt',
        30
    );
    // Make the default submenu item "App Bookings" instead of a duplicate "Lubowa"
    add_submenu_page('lubowa', 'App Bookings', 'App Bookings', 'manage_options', 'lubowa', 'lubowa_admin_bookings_page');
    add_submenu_page('lubowa', 'Leagues', 'Leagues', 'manage_options', 'lubowa-leagues', 'lubowa_admin_leagues_page');
    add_submenu_page('lubowa', 'App Users', 'App Users', 'manage_options', 'lubowa-app-users', 'lubowa_admin_app_users_page');
});

function lubowa_admin_bookings_page() {
    if (!current_user_can('manage_options')) {
        return;
    }
    global $wpdb;
    $table = LUBOWA_BOOKINGS_TABLE;
    $allowed_statuses = ['pending', 'approved', 'canceled', 'rejected'];

    // Handle status update
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_update_booking_status']) && check_admin_referer('lubowa_update_booking_status')) {
        $id     = (int) ($_POST['booking_id'] ?? 0);
        $status = strtolower(sanitize_text_field($_POST['booking_status'] ?? ''));
        if ($id > 0 && in_array($status, $allowed_statuses, true)) {
            $wpdb->update($table, ['status' => $status], ['id' => $id]);
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa'));
        exit;
    }

    // Handle delete
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_delete_booking']) && check_admin_referer('lubowa_delete_booking')) {
        $id = (int) ($_POST['booking_id'] ?? 0);
        if ($id > 0) {
            $wpdb->delete($table, ['id' => $id]);
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa'));
        exit;
    }
    $rows  = $wpdb->get_results("SELECT id, date, time_slot, contact_name, contact_phone, contact_email, notes, service, status, created_at FROM $table ORDER BY created_at DESC", ARRAY_A);

    $screen = get_current_screen();
    if ($screen && in_array($screen->id, ['toplevel_page_lubowa', 'lubowa_page_lubowa'], true)) {
        echo '<style>
        .lubowa-app-bookings .wrap { max-width: 100%; }
        .lubowa-app-bookings .wrap h1 { font-size: 23px; font-weight: 400; margin: 0 0 8px 0; color: #1d2327; }
        .lubowa-app-bookings .wrap > p:first-of-type { color: #646970; margin: 0 0 20px 0; font-size: 14px; }
        .lubowa-app-bookings .wrap > p:last-of-type { margin: 1em 0; color: #646970; }
        .lubowa-app-bookings .wp-list-table { margin-top: 12px; border: 1px solid #c3c4c7; box-shadow: 0 1px 1px rgba(0,0,0,.04); border-collapse: collapse; table-layout: auto !important; width: 100%; }
        .lubowa-app-bookings .wp-list-table th { padding: 10px 14px; white-space: nowrap; }
        .lubowa-app-bookings .wp-list-table td { padding: 10px 14px; vertical-align: middle; }
        .lubowa-app-bookings .wp-list-table thead th { background: #f6f7f7; color: #1d2327; font-weight: 600; border-bottom: 1px solid #c3c4c7; }
        .lubowa-app-bookings .wp-list-table tbody tr:hover { background: #f6f7f7; }
        .lubowa-app-bookings .wp-list-table a[href^="mailto:"] { color: #2271b1; text-decoration: none; }
        .lubowa-app-bookings .wp-list-table a[href^="mailto:"]:hover { text-decoration: underline; }
        .lubowa-app-bookings .wp-list-table .status { display: inline-block; padding: 4px 10px; border-radius: 4px; font-size: 12px; font-weight: 500; white-space: nowrap; }
        .lubowa-app-bookings .wp-list-table .status-pending { background: #fcf0e3; color: #94660c; }
        .lubowa-app-bookings .wp-list-table .status-approved { background: #d4edda; color: #155724; }
        .lubowa-app-bookings .wp-list-table .status-canceled { background: #f8d7da; color: #721c24; }
        .lubowa-app-bookings .wp-list-table .status-rejected { background: #e2e3e5; color: #383d41; }
        .lubowa-app-bookings .booking-status-cell { min-width: 220px; }
        .lubowa-app-bookings .booking-status-cell form { display: inline-flex; align-items: center; gap: 6px; margin: 0 6px 0 0; }
        .lubowa-app-bookings .booking-status-cell select { min-width: 120px; }
        .lubowa-app-bookings .col-email { min-width: 200px; word-break: break-all; }
        .lubowa-app-bookings .col-phone { white-space: nowrap; }
        .lubowa-app-bookings .col-note { max-width: 180px; word-break: break-word; }
        .lubowa-app-bookings .col-date { white-space: nowrap; }
        .lubowa-app-bookings .col-time { white-space: nowrap; }
        .lubowa-app-bookings .col-created { white-space: nowrap; }
        .lubowa-app-bookings .lubowa-empty-state { padding: 24px; text-align: center; color: #646970; background: #f6f7f7; border: 1px dashed #c3c4c7; border-radius: 4px; margin: 16px 0; }
        </style>';
    }
    ?>
    <div class="wrap lubowa-app-bookings">
        <h1>Lubowa App Bookings</h1>
        <p>Bookings submitted from the mobile app. (Amelia calendar shows website bookings only.)</p>
        <?php if (empty($rows)) : ?>
            <p class="lubowa-empty-state">No app bookings yet.</p>
        <?php else : ?>
            <table class="wp-list-table widefat striped">
                <thead>
                    <tr>
                        <th class="col-date">Booked For</th>
                        <th class="col-time">Booked Time</th>
                        <th>Customer</th>
                        <th>Service</th>
                        <th>Status</th>
                        <th class="col-email">Customer Email</th>
                        <th class="col-phone">Customer Phone</th>
                        <th class="col-note">Note</th>
                        <th class="col-created">Created At</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($rows as $r) : ?>
                        <?php
                        $ts = strtotime($r['time_slot']);
                        $mins = ($ts !== false) ? (int) date('i', $ts) : 0;
                        $time_disp = ($ts !== false) ? ($mins === 0 ? date('ga', $ts) : date('g:ia', $ts)) : $r['time_slot'];
                        ?>
                        <tr>
                            <td class="col-date"><?php echo esc_html($r['date']); ?></td>
                            <td class="col-time"><?php echo esc_html($time_disp); ?></td>
                            <td><?php echo esc_html($r['contact_name']); ?></td>
                            <td><?php echo esc_html((isset($r['service']) && $r['service'] !== '') ? $r['service'] : 'Court booking'); ?></td>
                            <td class="booking-status-cell">
                                <form method="post">
                                    <?php wp_nonce_field('lubowa_update_booking_status'); ?>
                                    <input type="hidden" name="lubowa_update_booking_status" value="1" />
                                    <input type="hidden" name="booking_id" value="<?php echo (int) $r['id']; ?>" />
                                    <select name="booking_status">
                                        <?php foreach ($allowed_statuses as $st) : ?>
                                            <option value="<?php echo esc_attr($st); ?>" <?php selected(strtolower($r['status']) === $st); ?>>
                                                <?php echo esc_html(ucfirst($st)); ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                    <button type="submit" class="button button-small">Save</button>
                                </form>
                                <form method="post" onsubmit="return confirm('Delete this booking? This cannot be undone.');">
                                    <?php wp_nonce_field('lubowa_delete_booking'); ?>
                                    <input type="hidden" name="lubowa_delete_booking" value="1" />
                                    <input type="hidden" name="booking_id" value="<?php echo (int) $r['id']; ?>" />
                                    <button type="submit" class="button-link-delete">Delete</button>
                                </form>
                            </td>
                            <td class="col-email"><a href="mailto:<?php echo esc_attr($r['contact_email']); ?>"><?php echo esc_html($r['contact_email']); ?></a></td>
                            <td class="col-phone"><?php echo esc_html($r['contact_phone']); ?></td>
                            <td class="col-note"><?php echo esc_html($r['notes']); ?></td>
                            <td class="col-created"><?php echo esc_html($r['created_at']); ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
    <?php
}

function lubowa_admin_app_users_page() {
    if (!current_user_can('manage_options')) {
        return;
    }

    $per_page = 20;
    $page = isset($_GET['paged']) ? max(1, (int) $_GET['paged']) : 1;
    $search = isset($_GET['s']) ? trim(sanitize_text_field(wp_unslash($_GET['s']))) : '';
    $offset = ($page - 1) * $per_page;

    // Handle block/unblock
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_toggle_block']) && check_admin_referer('lubowa_toggle_block')) {
        $user_id = (int) ($_POST['user_id'] ?? 0);
        if ($user_id > 0) {
            $current = get_user_meta($user_id, 'lubowa_blocked', true);
            $blocked = ($current === '1' || $current === true);
            update_user_meta($user_id, 'lubowa_blocked', $blocked ? '0' : '1');
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-app-users&paged=' . $page . ($search !== '' ? '&s=' . rawurlencode($search) : '')));
        exit;
    }

    $args = [
        'role'   => 'lubowa_app_user',
        'number' => $per_page,
        'offset' => $offset,
        'orderby' => 'registered',
        'order'   => 'DESC',
        'fields'  => 'all',
    ];
    if ($search !== '') {
        $args['search'] = '*' . $search . '*';
        $args['search_columns'] = ['user_login', 'user_email', 'display_name'];
    }

    $users = get_users($args);
    $total = count_users();
    $role_total = isset($total['avail_roles']['lubowa_app_user']) ? (int) $total['avail_roles']['lubowa_app_user'] : 0;
    if ($search !== '') {
        $count_args = array_merge($args, ['number' => -1, 'offset' => 0, 'count_total' => true]);
        $count_query = new WP_User_Query($count_args);
        $role_total = $count_query->get_total();
    }
    $total_pages = $role_total > 0 ? (int) ceil($role_total / $per_page) : 1;

    $screen = get_current_screen();
    if ($screen && $screen->id === 'lubowa_page_lubowa-app-users') {
        echo '<style>
        .lubowa-app-users .wrap { max-width: 100%; }
        .lubowa-app-users .wrap h1 { font-size: 23px; font-weight: 400; margin: 0 0 8px 0; }
        .lubowa-app-users .wp-list-table { margin-top: 12px; border: 1px solid #c3c4c7; box-shadow: 0 1px 1px rgba(0,0,0,.04); border-collapse: collapse; width: 100%; }
        .lubowa-app-users .wp-list-table th, .lubowa-app-users .wp-list-table td { padding: 10px 14px; vertical-align: middle; }
        .lubowa-app-users .wp-list-table thead th { background: #f6f7f7; font-weight: 600; border-bottom: 1px solid #c3c4c7; }
        .lubowa-app-users .wp-list-table tbody tr:hover { background: #f6f7f7; }
        .lubowa-app-users .col-email { word-break: break-all; }
        .lubowa-app-users .col-created { white-space: nowrap; }
        .lubowa-app-users .status-blocked { background: #f8d7da; color: #721c24; padding: 4px 10px; border-radius: 4px; font-size: 12px; }
        .lubowa-app-users .status-ok { color: #155724; font-size: 12px; }
        .lubowa-app-users .lubowa-empty-state { padding: 24px; text-align: center; color: #646970; background: #f6f7f7; border: 1px dashed #c3c4c7; border-radius: 4px; margin: 16px 0; }
        .lubowa-app-users .search-box { margin-bottom: 16px; }
        </style>';
    }
    ?>
    <div class="wrap lubowa-app-users">
        <h1>App Users</h1>
        <p>Users who signed up from the mobile app (role: Lubowa App User). Blocked users cannot use the app API.</p>

        <form method="get" class="search-box">
            <input type="hidden" name="page" value="lubowa-app-users" />
            <input type="search" name="s" value="<?php echo esc_attr($search); ?>" placeholder="Search by name, email, username..." style="width: 280px;" />
            <button type="submit" class="button">Search</button>
            <?php if ($search !== '') : ?>
                <a href="<?php echo esc_url(admin_url('admin.php?page=lubowa-app-users')); ?>" class="button">Clear</a>
            <?php endif; ?>
        </form>

        <?php if (empty($users)) : ?>
            <p class="lubowa-empty-state"><?php echo esc_html($search !== '' ? 'No app users match your search.' : 'No app users yet.'); ?></p>
        <?php else : ?>
            <table class="wp-list-table widefat striped">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Username</th>
                        <th>Display name</th>
                        <th class="col-email">Email</th>
                        <th>Roles</th>
                        <th>Status</th>
                        <th class="col-created">Registered</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($users as $u) :
                        $blocked = get_user_meta($u->ID, 'lubowa_blocked', true);
                        $is_blocked = ($blocked === '1' || $blocked === true);
                        $edit_link = get_edit_user_link($u->ID);
                    ?>
                        <tr>
                            <td><?php echo (int) $u->ID; ?></td>
                            <td><?php echo esc_html($u->user_login); ?></td>
                            <td><?php echo esc_html($u->display_name ?: '—'); ?></td>
                            <td class="col-email"><a href="mailto:<?php echo esc_attr($u->user_email); ?>"><?php echo esc_html($u->user_email); ?></a></td>
                            <td><?php echo esc_html(implode(', ', $u->roles)); ?></td>
                            <td>
                                <?php if ($is_blocked) : ?>
                                    <span class="status-blocked">Blocked</span>
                                <?php else : ?>
                                    <span class="status-ok">Active</span>
                                <?php endif; ?>
                            </td>
                            <td class="col-created"><?php echo esc_html($u->user_registered); ?></td>
                            <td>
                                <form method="post" style="display: inline;">
                                    <?php wp_nonce_field('lubowa_toggle_block'); ?>
                                    <input type="hidden" name="lubowa_toggle_block" value="1" />
                                    <input type="hidden" name="user_id" value="<?php echo (int) $u->ID; ?>" />
                                    <button type="submit" class="button button-small"><?php echo $is_blocked ? 'Unblock' : 'Block'; ?></button>
                                </form>
                                <?php if ($edit_link) : ?>
                                    <a href="<?php echo esc_url($edit_link); ?>" class="button button-small">Edit user</a>
                                <?php endif; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>

            <?php if ($total_pages > 1) : ?>
                <p class="pagination-links" style="margin-top: 16px;">
                    <?php
                    $base = admin_url('admin.php?page=lubowa-app-users&paged=%#%');
                    if ($search !== '') {
                        $base = add_query_arg('s', rawurlencode($search), $base);
                    }
                    echo paginate_links([
                        'base'      => $base,
                        'format'    => '',
                        'prev_text' => '&laquo;',
                        'next_text' => '&raquo;',
                        'total'     => $total_pages,
                        'current'   => $page,
                    ]);
                    ?>
                    <span style="margin-left: 8px; color: #646970;"><?php echo (int) $role_total; ?> user(s)</span>
                </p>
            <?php endif; ?>
        <?php endif; ?>
    </div>
    <?php
}

function lubowa_admin_leagues_page() {
    if (!current_user_can('manage_options')) {
        return;
    }
    $league_id = isset($_GET['league_id']) ? (int) $_GET['league_id'] : 0;
    if ($league_id > 0) {
        lubowa_admin_league_single_page($league_id);
        return;
    }

    global $wpdb;
    $table = LUBOWA_LEAGUES_TABLE;
    $bookings_table = LUBOWA_BOOKINGS_TABLE;
    $leagues = $wpdb->get_results("SELECT id, name, code, legs, booking_id, created_at FROM $table ORDER BY created_at DESC", ARRAY_A);
    $app_bookings = $wpdb->get_results("SELECT id, date, time_slot, contact_name FROM $bookings_table ORDER BY date DESC, id DESC LIMIT 200", ARRAY_A);

    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_add_league']) && check_admin_referer('lubowa_add_league')) {
        $name = sanitize_text_field($_POST['league_name'] ?? '');
        $legs = isset($_POST['league_legs']) ? max(1, min(10, (int) $_POST['league_legs'])) : 1;
        $booking_id = isset($_POST['league_booking_id']) ? (int) $_POST['league_booking_id'] : null;
        if ($name !== '') {
            $code = lubowa_api_league_code();
            $insert = ['name' => $name, 'code' => $code, 'legs' => $legs];
            if ($booking_id > 0) {
                $insert['booking_id'] = $booking_id;
            }
            $wpdb->insert($table, $insert);
            if ($wpdb->last_error) {
                wp_die('DB error: ' . esc_html($wpdb->last_error));
            }
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues'));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_edit_league']) && check_admin_referer('lubowa_edit_league')) {
        $id = (int) ($_POST['league_id'] ?? 0);
        $name = sanitize_text_field($_POST['league_name'] ?? '');
        $code = sanitize_text_field($_POST['league_code'] ?? '');
        $legs = isset($_POST['league_legs']) ? max(1, min(10, (int) $_POST['league_legs'])) : 1;
        $booking_id = isset($_POST['league_booking_id']) ? (int) $_POST['league_booking_id'] : null;
        if ($id > 0 && $name !== '') {
            $updates = ['name' => $name, 'legs' => $legs, 'booking_id' => $booking_id > 0 ? $booking_id : null];
            if ($code !== '') {
                $updates['code'] = $code;
            }
            $wpdb->update($table, $updates, ['id' => $id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues'));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_delete_league']) && check_admin_referer('lubowa_delete_league')) {
        $id = (int) ($_POST['league_id'] ?? 0);
        if ($id > 0) {
            $team_ids = $wpdb->get_col($wpdb->prepare("SELECT id FROM " . LUBOWA_TEAMS_TABLE . " WHERE league_id = %d", $id));
            foreach ($team_ids as $tid) {
                $wpdb->delete(LUBOWA_PLAYERS_TABLE, ['team_id' => $tid]);
            }
            $wpdb->delete(LUBOWA_TEAMS_TABLE, ['league_id' => $id]);
            $wpdb->delete(LUBOWA_FIXTURES_TABLE, ['league_id' => $id]);
            $wpdb->delete($table, ['id' => $id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues'));
            exit;
        }
    }
    $edit_league_id = isset($_GET['edit_league']) ? (int) $_GET['edit_league'] : 0;
    $edit_league = $edit_league_id > 0 ? $wpdb->get_row($wpdb->prepare("SELECT id, name, code, legs, booking_id FROM $table WHERE id = %d", $edit_league_id), ARRAY_A) : null;
    ?>
    <div class="wrap lubowa-admin">
        <h1>Leagues</h1>
        <p>Create and manage leagues. Use the app with JWT to manage in detail, or use this page to list and add leagues.</p>

        <h2>Add league</h2>
        <form method="post" style="max-width: 400px; margin-bottom: 24px;">
            <?php wp_nonce_field('lubowa_add_league'); ?>
            <input type="hidden" name="lubowa_add_league" value="1" />
            <p>
                <label for="league_name">Name</label><br />
                <input type="text" id="league_name" name="league_name" required class="regular-text" />
            </p>
            <p>
                <label for="league_legs">Legs</label><br />
                <input type="number" id="league_legs" name="league_legs" value="1" min="1" max="10" /> (1 = one fixture per pair; 2 = A vs B and B vs A per pair)
            </p>
            <p>
                <label for="league_booking_id">Link to app booking (pitch)</label><br />
                <select id="league_booking_id" name="league_booking_id">
                    <option value="">— None —</option>
                    <?php foreach ($app_bookings as $b) : ?>
                        <option value="<?php echo (int) $b['id']; ?>">#<?php echo (int) $b['id']; ?> — <?php echo esc_html($b['date']); ?> <?php echo esc_html($b['time_slot']); ?> — <?php echo esc_html($b['contact_name']); ?></option>
                    <?php endforeach; ?>
                </select>
            </p>
            <p><input type="submit" class="button button-primary" value="Add league" /></p>
        </form>

        <?php if ($edit_league) : ?>
        <h2>Edit league</h2>
        <form method="post" style="max-width: 400px; margin-bottom: 24px;">
            <?php wp_nonce_field('lubowa_edit_league'); ?>
            <input type="hidden" name="lubowa_edit_league" value="1" />
            <input type="hidden" name="league_id" value="<?php echo (int) $edit_league['id']; ?>" />
            <p><label>Name</label><br /><input type="text" name="league_name" value="<?php echo esc_attr($edit_league['name']); ?>" required class="regular-text" /></p>
            <p><label>Code</label><br /><input type="text" name="league_code" value="<?php echo esc_attr($edit_league['code']); ?>" class="regular-text" /></p>
            <p><label>Legs</label><br /><input type="number" name="league_legs" value="<?php echo (int) ($edit_league['legs'] ?? 1); ?>" min="1" max="10" /></p>
            <p><label>Link to app booking</label><br />
                <select name="league_booking_id">
                    <option value="">— None —</option>
                    <?php foreach ($app_bookings as $b) : ?>
                        <option value="<?php echo (int) $b['id']; ?>" <?php selected(isset($edit_league['booking_id']) && (int) $edit_league['booking_id'] === (int) $b['id']); ?>><?php echo (int) $b['id']; ?> — <?php echo esc_html($b['date'] . ' ' . $b['time_slot'] . ' ' . $b['contact_name']); ?></option>
                    <?php endforeach; ?>
                </select>
            </p>
            <p><input type="submit" class="button button-primary" value="Save" /> <a href="<?php echo esc_url(admin_url('admin.php?page=lubowa-leagues')); ?>">Cancel</a></p>
        </form>
        <?php endif; ?>

        <h2>All leagues</h2>
        <?php if (empty($leagues)) : ?>
            <p>No leagues yet.</p>
        <?php else : ?>
            <table class="wp-list-table widefat fixed striped">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Name</th>
                        <th>Code</th>
                        <th>Legs</th>
                        <th>Booking</th>
                        <th>Created</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $booking_ids = array_filter(array_column($leagues, 'booking_id'));
                    $bookings_by_id = [];
                    if (!empty($booking_ids)) {
                        $placeholders = implode(',', array_fill(0, count($booking_ids), '%d'));
                        $rows_b = $wpdb->get_results($wpdb->prepare("SELECT id, date, time_slot, contact_name FROM $bookings_table WHERE id IN ($placeholders)", ...$booking_ids), ARRAY_A);
                        foreach ($rows_b as $rb) {
                            $bookings_by_id[(int) $rb['id']] = $rb;
                        }
                    }
                    foreach ($leagues as $l) :
                        $bid = isset($l['booking_id']) ? (int) $l['booking_id'] : 0;
                        $brow = $bid > 0 && isset($bookings_by_id[$bid]) ? $bookings_by_id[$bid] : null;
                    ?>
                        <tr>
                            <td><?php echo (int) $l['id']; ?></td>
                            <td><?php echo esc_html($l['name']); ?></td>
                            <td><code><?php echo esc_html($l['code']); ?></code></td>
                            <td><?php echo (int) ($l['legs'] ?? 1); ?></td>
                            <td><?php echo $brow ? '#' . (int) $brow['id'] . ' ' . esc_html($brow['date'] . ' ' . $brow['time_slot']) : '—'; ?></td>
                            <td><?php echo esc_html($l['created_at']); ?></td>
                            <td>
                                <a href="<?php echo esc_url(admin_url('admin.php?page=lubowa-leagues&league_id=' . $l['id'])); ?>">Manage</a>
                                | <a href="<?php echo esc_url(admin_url('admin.php?page=lubowa-leagues&edit_league=' . $l['id'])); ?>">Edit</a>
                                | <form method="post" style="display:inline;" onsubmit="return confirm('Delete this league and all its teams, players and fixtures?');">
                                    <?php wp_nonce_field('lubowa_delete_league'); ?>
                                    <input type="hidden" name="lubowa_delete_league" value="1" />
                                    <input type="hidden" name="league_id" value="<?php echo (int) $l['id']; ?>" />
                                    <button type="submit" class="button-link-delete">Delete</button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
    <?php
}

function lubowa_admin_league_single_page($league_id) {
    if (!current_user_can('manage_options')) {
        return;
    }
    global $wpdb;
    $league = $wpdb->get_row($wpdb->prepare("SELECT id, name, code, legs, booking_id FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id), ARRAY_A);
    if (!$league) {
        echo '<div class="wrap"><p>League not found.</p></div>';
        return;
    }
    $app_bookings = $wpdb->get_results("SELECT id, date, time_slot, contact_name FROM " . LUBOWA_BOOKINGS_TABLE . " ORDER BY date DESC, id DESC LIMIT 200", ARRAY_A);

    $teams_table   = LUBOWA_TEAMS_TABLE;
    $fix_table     = LUBOWA_FIXTURES_TABLE;
    $players_table = LUBOWA_PLAYERS_TABLE;
    $teams         = $wpdb->get_results($wpdb->prepare("SELECT id, name, leader_user_id FROM $teams_table WHERE league_id = %d ORDER BY name", $league_id), ARRAY_A);
    $players_by_team = [];
    if (!empty($teams)) {
        $team_ids = array_column($teams, 'id');
        $placeholders = implode(',', array_fill(0, count($team_ids), '%d'));
        $all_players = $wpdb->get_results($wpdb->prepare(
            "SELECT id, name, goals, team_id FROM $players_table WHERE team_id IN ($placeholders) ORDER BY name",
            ...$team_ids
        ), ARRAY_A);
        foreach ($all_players as $p) {
            $players_by_team[(int) $p['team_id']][] = $p;
        }
    }
    $fixtures = $wpdb->get_results($wpdb->prepare(
        "SELECT f.id, f.home_goals, f.away_goals, f.result_confirmed, f.match_date, f.match_time, f.started_at, ht.name AS home_name, at.name AS away_name FROM $fix_table f JOIN $teams_table ht ON f.home_team_id = ht.id JOIN $teams_table at ON f.away_team_id = at.id WHERE f.league_id = %d ORDER BY f.match_date ASC, f.sort_order",
        $league_id
    ), ARRAY_A);

    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_add_player']) && check_admin_referer('lubowa_add_player_' . $league_id)) {
        $team_id = (int) ($_POST['team_id'] ?? 0);
        $name = sanitize_text_field($_POST['player_name'] ?? '');
        if ($team_id > 0 && $name !== '') {
            $team = $wpdb->get_row($wpdb->prepare("SELECT id FROM $teams_table WHERE id = %d AND league_id = %d", $team_id, $league_id));
            if ($team) {
                $count = $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $players_table WHERE team_id = %d", $team_id));
                if ($count < 8) {
                    $wpdb->insert($players_table, ['team_id' => $team_id, 'name' => $name, 'goals' => 0]);
                }
            }
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_add_team']) && check_admin_referer('lubowa_add_team_' . $league_id)) {
        $name = sanitize_text_field($_POST['team_name'] ?? '');
        if ($name !== '') {
            $wpdb->insert($teams_table, ['league_id' => $league_id, 'name' => $name]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_generate_fixtures']) && check_admin_referer('lubowa_fixtures_' . $league_id)) {
        $league_row = $wpdb->get_row($wpdb->prepare("SELECT legs FROM " . LUBOWA_LEAGUES_TABLE . " WHERE id = %d", $league_id), ARRAY_A);
        $legs = ($league_row && isset($league_row['legs'])) ? max(1, min(10, (int) $league_row['legs'])) : 1;
        $team_ids = $wpdb->get_col($wpdb->prepare("SELECT id FROM $teams_table WHERE league_id = %d ORDER BY id", $league_id));
        if (count($team_ids) >= 2) {
            $wpdb->delete($fix_table, ['league_id' => $league_id]);
            $order = 0;
            $match_date = current_time('Y-m-d');
            // 1 leg = one fixture per pair; 2 legs = A vs B and B vs A. Pairs (i,j) with i < j; each pair gets legs fixtures.
            for ($i = 0; $i < count($team_ids); $i++) {
                for ($j = $i + 1; $j < count($team_ids); $j++) {
                    for ($leg = 0; $leg < $legs; $leg++) {
                        $home = ($leg % 2 === 0) ? $team_ids[$i] : $team_ids[$j];
                        $away = ($leg % 2 === 0) ? $team_ids[$j] : $team_ids[$i];
                        $wpdb->insert($fix_table, [
                            'league_id'        => $league_id,
                            'home_team_id'     => $home,
                            'away_team_id'     => $away,
                            'match_date'       => $match_date,
                            'result_confirmed' => 0,
                            'sort_order'       => $order++,
                        ]);
                    }
                }
            }
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_reset_fixtures']) && check_admin_referer('lubowa_fixtures_' . $league_id)) {
        $wpdb->delete($fix_table, ['league_id' => $league_id]);
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_update_fixture']) && check_admin_referer('lubowa_update_fixture')) {
        $fid = (int) ($_POST['fixture_id'] ?? 0);
        $hg  = (int) ($_POST['home_goals'] ?? 0);
        $ag  = (int) ($_POST['away_goals'] ?? 0);
        if ($fid > 0) {
            $wpdb->update($fix_table, ['home_goals' => $hg, 'away_goals' => $ag], ['id' => $fid]);
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_clear_fixture']) && check_admin_referer('lubowa_clear_fixture')) {
        $fid = (int) ($_POST['fixture_id'] ?? 0);
        if ($fid > 0) {
            $wpdb->update($fix_table, ['home_goals' => null, 'away_goals' => null, 'result_confirmed' => 0], ['id' => $fid]);
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_full_time']) && check_admin_referer('lubowa_full_time')) {
        $fid = (int) ($_POST['fixture_id'] ?? 0);
        if ($fid > 0) {
            $f = $wpdb->get_row($wpdb->prepare("SELECT home_goals, away_goals FROM $fix_table WHERE id = %d", $fid));
            if ($f && $f->home_goals !== null && $f->away_goals !== null) {
                $wpdb->update($fix_table, ['result_confirmed' => 1], ['id' => $fid]);
            }
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_revert_fixture']) && check_admin_referer('lubowa_revert_fixture')) {
        $fid = (int) ($_POST['fixture_id'] ?? 0);
        if ($fid > 0) {
            $wpdb->update($fix_table, ['result_confirmed' => 0], ['id' => $fid]);
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_start_fixture']) && check_admin_referer('lubowa_start_fixture')) {
        $fid = (int) ($_POST['fixture_id'] ?? 0);
        if ($fid > 0) {
            $wpdb->update($fix_table, ['started_at' => current_time('mysql')], ['id' => $fid]);
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_update_fixture_date']) && check_admin_referer('lubowa_update_fixture_date')) {
        $fid = (int) ($_POST['fixture_id'] ?? 0);
        $date = sanitize_text_field($_POST['match_date'] ?? '');
        $time = sanitize_text_field($_POST['match_time'] ?? '');
        if ($fid > 0) {
            $up = [];
            if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                $up['match_date'] = $date;
            }
            $up['match_time'] = ($time !== '') ? $time : null;
            if (!empty($up)) {
                $wpdb->update($fix_table, $up, ['id' => $fid]);
            }
        }
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_edit_league_single']) && check_admin_referer('lubowa_edit_league_single_' . $league_id)) {
        $name = sanitize_text_field($_POST['league_name'] ?? '');
        $code = sanitize_text_field($_POST['league_code'] ?? '');
        $legs = isset($_POST['league_legs']) ? max(1, min(10, (int) $_POST['league_legs'])) : 1;
        $booking_id = isset($_POST['league_booking_id']) ? (int) $_POST['league_booking_id'] : null;
        if ($name !== '') {
            $up = ['name' => $name, 'legs' => $legs, 'booking_id' => $booking_id > 0 ? $booking_id : null];
            if ($code !== '') {
                $up['code'] = $code;
            }
            $wpdb->update(LUBOWA_LEAGUES_TABLE, $up, ['id' => $league_id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_delete_league_single']) && check_admin_referer('lubowa_delete_league_single_' . $league_id)) {
        $team_ids = $wpdb->get_col($wpdb->prepare("SELECT id FROM $teams_table WHERE league_id = %d", $league_id));
        foreach ($team_ids as $tid) {
            $wpdb->delete($players_table, ['team_id' => $tid]);
        }
        $wpdb->delete($teams_table, ['league_id' => $league_id]);
        $wpdb->delete($fix_table, ['league_id' => $league_id]);
        $wpdb->delete(LUBOWA_LEAGUES_TABLE, ['id' => $league_id]);
        wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues'));
        exit;
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_edit_team']) && check_admin_referer('lubowa_edit_team_' . $league_id)) {
        $team_id = (int) ($_POST['team_id'] ?? 0);
        $name = sanitize_text_field($_POST['team_name'] ?? '');
        $leader_user_id = isset($_POST['team_leader_user_id']) ? (int) $_POST['team_leader_user_id'] : null;
        if ($team_id > 0 && $name !== '') {
            $up = ['name' => $name];
            $up['leader_user_id'] = $leader_user_id > 0 ? $leader_user_id : null;
            $wpdb->update($teams_table, $up, ['id' => $team_id, 'league_id' => $league_id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_delete_team']) && check_admin_referer('lubowa_delete_team_' . $league_id)) {
        $team_id = (int) ($_POST['team_id'] ?? 0);
        if ($team_id > 0) {
            $wpdb->delete($players_table, ['team_id' => $team_id]);
            $wpdb->delete($fix_table, ['home_team_id' => $team_id]);
            $wpdb->delete($fix_table, ['away_team_id' => $team_id]);
            $wpdb->delete($teams_table, ['id' => $team_id, 'league_id' => $league_id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_edit_player']) && check_admin_referer('lubowa_edit_player_' . $league_id)) {
        $player_id = (int) ($_POST['player_id'] ?? 0);
        $name = sanitize_text_field($_POST['player_name'] ?? '');
        $goals = (int) ($_POST['player_goals'] ?? 0);
        if ($player_id > 0 && $name !== '') {
            $wpdb->update($players_table, ['name' => $name, 'goals' => $goals], ['id' => $player_id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lubowa_delete_player']) && check_admin_referer('lubowa_delete_player_' . $league_id)) {
        $player_id = (int) ($_POST['player_id'] ?? 0);
        if ($player_id > 0) {
            $wpdb->delete($players_table, ['id' => $player_id]);
            wp_safe_redirect(admin_url('admin.php?page=lubowa-leagues&league_id=' . $league_id));
            exit;
        }
    }
    $wp_users = get_users(['orderby' => 'display_name', 'number' => 500]);
    ?>
    <div class="wrap lubowa-admin">
        <p><a href="<?php echo esc_url(admin_url('admin.php?page=lubowa-leagues')); ?>">&larr; Back to Leagues</a></p>
        <h1><?php echo esc_html($league['name']); ?></h1>
        <p>Code: <code><?php echo esc_html($league['code']); ?></code> (share for public standings) &middot; Legs: <?php echo (int) ($league['legs'] ?? 1); ?><?php if (!empty($league['booking_id'])) : ?> &middot; Booking #<?php echo (int) $league['booking_id']; ?><?php endif; ?></p>
        <p>
            <form method="post" style="display:inline-block; margin-right: 8px;">
                <?php wp_nonce_field('lubowa_edit_league_single_' . $league_id); ?>
                <input type="hidden" name="lubowa_edit_league_single" value="1" />
                <input type="text" name="league_name" value="<?php echo esc_attr($league['name']); ?>" placeholder="League name" />
                <input type="text" name="league_code" value="<?php echo esc_attr($league['code']); ?>" placeholder="Code" style="width: 80px;" />
                <input type="number" name="league_legs" value="<?php echo (int) ($league['legs'] ?? 1); ?>" min="1" max="10" style="width: 50px;" title="Legs" />
                <select name="league_booking_id" title="Link to app booking">
                    <option value="">No booking</option>
                    <?php foreach ($app_bookings as $b) : ?>
                        <option value="<?php echo (int) $b['id']; ?>" <?php selected(isset($league['booking_id']) && (int) $league['booking_id'] === (int) $b['id']); ?>><?php echo (int) $b['id']; ?> <?php echo esc_html($b['date'] . ' ' . $b['time_slot']); ?></option>
                    <?php endforeach; ?>
                </select>
                <input type="submit" class="button" value="Update league" />
            </form>
            <form method="post" style="display:inline;" onsubmit="return confirm('Delete this league and all teams, players and fixtures?');">
                <?php wp_nonce_field('lubowa_delete_league_single_' . $league_id); ?>
                <input type="hidden" name="lubowa_delete_league_single" value="1" />
                <button type="submit" class="button">Delete league</button>
            </form>
        </p>

        <h2>Teams</h2>
        <form method="post" style="margin-bottom: 16px;">
            <?php wp_nonce_field('lubowa_add_team_' . $league_id); ?>
            <input type="hidden" name="lubowa_add_team" value="1" />
            <input type="text" name="team_name" placeholder="Team name" required />
            <input type="submit" class="button button-primary" value="Add team" />
        </form>
        <?php if (empty($teams)) : ?>
            <p>No teams yet. Add at least 2 to generate fixtures.</p>
        <?php else : ?>
            <?php foreach ($teams as $t) :
                $team_players = isset($players_by_team[$t['id']]) ? $players_by_team[$t['id']] : [];
            ?>
            <div style="margin-bottom: 20px; padding: 12px; background: #f6f7f7; border: 1px solid #c3c4c7; border-radius: 4px; max-width: 600px;">
                <div style="display:flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    <strong><?php echo esc_html($t['name']); ?></strong>
                    <form method="post" style="display:inline;">
                        <?php wp_nonce_field('lubowa_edit_team_' . $league_id); ?>
                        <input type="hidden" name="lubowa_edit_team" value="1" />
                        <input type="hidden" name="team_id" value="<?php echo (int) $t['id']; ?>" />
                        <input type="text" name="team_name" value="<?php echo esc_attr($t['name']); ?>" style="width: 120px;" />
                        <label>Team leader:</label>
                        <select name="team_leader_user_id" style="width: 160px;">
                            <option value="">— None —</option>
                            <?php foreach ($wp_users as $u) : ?>
                                <option value="<?php echo (int) $u->ID; ?>" <?php selected((int) ($t['leader_user_id'] ?? 0), (int) $u->ID); ?>><?php echo esc_html($u->display_name . ' (' . $u->user_login . ')'); ?></option>
                            <?php endforeach; ?>
                        </select>
                        <input type="submit" class="button button-small" value="Update" />
                    </form>
                    <form method="post" style="display:inline;" onsubmit="return confirm('Delete this team and its players?');">
                        <?php wp_nonce_field('lubowa_delete_team_' . $league_id); ?>
                        <input type="hidden" name="lubowa_delete_team" value="1" />
                        <input type="hidden" name="team_id" value="<?php echo (int) $t['id']; ?>" />
                        <button type="submit" class="button button-small">Delete team</button>
                    </form>
                </div>
                <form method="post" style="display:flex; gap: 8px; align-items: center; margin-top: 8px;">
                    <?php wp_nonce_field('lubowa_add_player_' . $league_id); ?>
                    <input type="hidden" name="lubowa_add_player" value="1" />
                    <input type="hidden" name="team_id" value="<?php echo (int) $t['id']; ?>" />
                    <input type="text" name="player_name" placeholder="Player name" required style="width: 180px;" />
                    <input type="submit" class="button button-small" value="Add player" />
                </form>
                <?php if (!empty($team_players)) : ?>
                    <ul style="margin: 8px 0 0 0; padding-left: 20px;">
                        <?php foreach ($team_players as $p) : ?>
                            <li>
                                <form method="post" style="display:inline;" class="lubowa-inline-form">
                                    <?php wp_nonce_field('lubowa_edit_player_' . $league_id); ?>
                                    <input type="hidden" name="lubowa_edit_player" value="1" />
                                    <input type="hidden" name="player_id" value="<?php echo (int) $p['id']; ?>" />
                                    <input type="text" name="player_name" value="<?php echo esc_attr($p['name']); ?>" style="width: 120px;" />
                                    <input type="number" name="player_goals" value="<?php echo (int) $p['goals']; ?>" min="0" style="width: 50px;" />
                                    <input type="submit" class="button button-small" value="Update" />
                                </form>
                                <form method="post" style="display:inline;" onsubmit="return confirm('Remove this player?');">
                                    <?php wp_nonce_field('lubowa_delete_player_' . $league_id); ?>
                                    <input type="hidden" name="lubowa_delete_player" value="1" />
                                    <input type="hidden" name="player_id" value="<?php echo (int) $p['id']; ?>" />
                                    <button type="submit" class="button button-small">Delete</button>
                                </form>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                <?php else : ?>
                    <p style="margin: 8px 0 0 0; color: #646970; font-size: 13px;">No players yet.</p>
                <?php endif; ?>
            </div>
            <?php endforeach; ?>
        <?php endif; ?>

        <h2>Fixtures</h2>
        <?php if (count($teams) < 2) : ?>
            <p>Add at least 2 teams, then generate fixtures.</p>
        <?php else : ?>
            <form method="post" style="display:inline-block; margin-right: 8px;">
                <?php wp_nonce_field('lubowa_fixtures_' . $league_id); ?>
                <input type="hidden" name="lubowa_generate_fixtures" value="1" />
                <input type="submit" class="button" value="Generate fixtures" />
            </form>
            <form method="post" style="display:inline-block;">
                <?php wp_nonce_field('lubowa_fixtures_' . $league_id); ?>
                <input type="hidden" name="lubowa_reset_fixtures" value="1" />
                <input type="submit" class="button" value="Reset fixtures" onclick="return confirm('Clear all fixtures?');" />
            </form>
        <?php endif; ?>

        <?php if (!empty($fixtures)) : ?>
            <p style="margin-bottom: 8px;">Fixtures generated for today (<strong><?php echo esc_html(current_time('Y-m-d')); ?></strong>). Use <strong>Start</strong> when the match begins, then enter score and <strong>Full time</strong> when it ends.</p>
            <table class="wp-list-table widefat fixed striped" style="margin-top: 12px;">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Time</th>
                        <th>Match</th>
                        <th>Home</th>
                        <th>Away</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($fixtures as $f) :
                        $confirmed = !empty($f['result_confirmed']);
                        $started = !empty($f['started_at']);
                        $has_score = $f['home_goals'] !== null && $f['away_goals'] !== null && $f['home_goals'] !== '' && $f['away_goals'] !== '';
                        $status = $confirmed ? 'Full time' : ($started ? 'In play' : 'Pending');
                    ?>
                        <tr>
                            <td>
                                <form method="post" style="display:inline;">
                                    <?php wp_nonce_field('lubowa_update_fixture_date'); ?>
                                    <input type="hidden" name="lubowa_update_fixture_date" value="1" />
                                    <input type="hidden" name="fixture_id" value="<?php echo (int) $f['id']; ?>" />
                                    <input type="date" name="match_date" value="<?php echo esc_attr($f['match_date'] ?? ''); ?>" style="width: 120px;" />
                            </td>
                            <td>
                                    <input type="text" name="match_time" value="<?php echo esc_attr($f['match_time'] ?? ''); ?>" placeholder="14:00" style="width: 60px;" />
                                    <input type="submit" class="button button-small" value="Set" />
                                </form>
                            </td>
                            <td><?php echo esc_html($f['home_name'] . ' vs ' . $f['away_name']); ?></td>
                            <td><?php echo $f['home_goals'] !== null && $f['home_goals'] !== '' ? (int) $f['home_goals'] : '–'; ?></td>
                            <td><?php echo $f['away_goals'] !== null && $f['away_goals'] !== '' ? (int) $f['away_goals'] : '–'; ?></td>
                            <td><?php echo $confirmed ? '<strong>Full time</strong>' : ($started ? '<em>In play</em>' : 'Pending'); ?></td>
                            <td>
                                <?php if (!$started && !$confirmed) : ?>
                                <form method="post" style="display:inline;">
                                    <?php wp_nonce_field('lubowa_start_fixture'); ?>
                                    <input type="hidden" name="lubowa_start_fixture" value="1" />
                                    <input type="hidden" name="fixture_id" value="<?php echo (int) $f['id']; ?>" />
                                    <button type="submit" class="button button-small">Start</button>
                                </form>
                                <?php endif; ?>
                                <form method="post" style="display:inline;">
                                    <?php wp_nonce_field('lubowa_update_fixture'); ?>
                                    <input type="hidden" name="lubowa_update_fixture" value="1" />
                                    <input type="hidden" name="fixture_id" value="<?php echo (int) $f['id']; ?>" />
                                    <input type="number" name="home_goals" value="<?php echo (int) $f['home_goals']; ?>" min="0" style="width: 50px;" placeholder="0" />
                                    <input type="number" name="away_goals" value="<?php echo (int) $f['away_goals']; ?>" min="0" style="width: 50px;" placeholder="0" />
                                    <input type="submit" class="button button-small" value="Update" />
                                </form>
                                <?php if ($has_score && !$confirmed) : ?>
                                <form method="post" style="display:inline;">
                                    <?php wp_nonce_field('lubowa_full_time'); ?>
                                    <input type="hidden" name="lubowa_full_time" value="1" />
                                    <input type="hidden" name="fixture_id" value="<?php echo (int) $f['id']; ?>" />
                                    <button type="submit" class="button button-small button-primary">Full time</button>
                                </form>
                                <?php elseif ($confirmed) : ?>
                                <form method="post" style="display:inline;" onsubmit="return confirm('Revert to pending? Points will no longer count.');">
                                    <?php wp_nonce_field('lubowa_revert_fixture'); ?>
                                    <input type="hidden" name="lubowa_revert_fixture" value="1" />
                                    <input type="hidden" name="fixture_id" value="<?php echo (int) $f['id']; ?>" />
                                    <button type="submit" class="button button-small">Revert</button>
                                </form>
                                <?php endif; ?>
                                <form method="post" style="display:inline;" onsubmit="return confirm('Clear score for this match?');">
                                    <?php wp_nonce_field('lubowa_clear_fixture'); ?>
                                    <input type="hidden" name="lubowa_clear_fixture" value="1" />
                                    <input type="hidden" name="fixture_id" value="<?php echo (int) $f['id']; ?>" />
                                    <button type="submit" class="button button-small">Clear score</button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
    <?php
}

// --- Public shortcodes: leaderboard, top teams, top players ---
add_shortcode('lubowa_leaderboard', 'lubowa_shortcode_leaderboard');
add_shortcode('lubowa_top_teams', 'lubowa_shortcode_top_teams');
add_shortcode('lubowa_top_players', 'lubowa_shortcode_top_players');

function lubowa_shortcode_styles() {
    static $done = false;
    if ($done) {
        return;
    }
    $done = true;
    ?>
    <style>
    .lubowa-sc { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: #2c3e2e; }
    .lubowa-sc .lubowa-card { background: #f4f6f4; border-radius: 12px; padding: 1.25rem 1.5rem; margin-bottom: 1.5rem; box-shadow: 0 2px 8px rgba(0,0,0,.06); border: 1px solid #e2e6e2; }
    .lubowa-sc .lubowa-card h2, .lubowa-sc .lubowa-card h3 { margin: 0 0 0.5rem 0; font-size: 1.25rem; font-weight: 600; color: #1a2a1a; }
    .lubowa-sc .lubowa-league-code { font-size: 0.85rem; color: #5a6a5a; margin-bottom: 1rem; }
    .lubowa-sc .lubowa-league-code code { background: #e8ece8; padding: 2px 8px; border-radius: 4px; }
    .lubowa-sc table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
    .lubowa-sc th { text-align: left; padding: 0.5rem 0.6rem; background: #e4e8e4; color: #2c3e2e; font-weight: 600; border-radius: 6px 6px 0 0; }
    .lubowa-sc th:not(:first-child) { text-align: center; }
    .lubowa-sc td { padding: 0.5rem 0.6rem; border-bottom: 1px solid #e2e6e2; }
    .lubowa-sc td:not(:first-child):not(:nth-child(2)) { text-align: center; }
    .lubowa-sc tr:last-child td { border-bottom: none; }
    .lubowa-sc .lubowa-pts { font-weight: 700; color: #1a2a1a; }
    .lubowa-sc .lubowa-btn { display: inline-block; padding: 0.6rem 1.25rem; background: #3d5a3d; color: #fff !important; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 0.9rem; margin-top: 0.5rem; transition: background .2s; }
    .lubowa-sc .lubowa-btn:hover { background: #2d4a2d; color: #fff; }
    .lubowa-sc .lubowa-grid { display: grid; gap: 1.5rem; }
    .lubowa-sc .lubowa-grid-2 { grid-template-columns: repeat(2, 1fr); }
    @media (max-width: 640px) { .lubowa-sc .lubowa-grid-2 { grid-template-columns: 1fr; } }
    .lubowa-sc .lubowa-empty { color: #5a6a5a; font-size: 0.9rem; }
    .lubowa-sc .lubowa-list-item { padding: 0.5rem 0; border-bottom: 1px solid #e8ece8; display: flex; justify-content: space-between; align-items: center; }
    .lubowa-sc .lubowa-list-item:last-child { border-bottom: none; }
    .lubowa-sc .lubowa-badge { background: #3d5a3d; color: #fff; font-size: 0.75rem; font-weight: 600; padding: 2px 6px; border-radius: 4px; margin-left: 0.25rem; }
    </style>
    <?php
}

function lubowa_shortcode_leaderboard($atts) {
    global $wpdb;
    $atts = shortcode_atts(['limit' => 0, 'view_all_url' => ''], $atts, 'lubowa_leaderboard');
    $limit = (int) $atts['limit'];
    $view_all_url = trim($atts['view_all_url']);
    $leagues = $wpdb->get_results("SELECT id, name, code FROM " . LUBOWA_LEAGUES_TABLE . " ORDER BY name", ARRAY_A);
    if (empty($leagues)) {
        lubowa_shortcode_styles();
        return '<div class="lubowa-sc"><p class="lubowa-empty">No leagues yet.</p></div>';
    }
    if ($limit > 0) {
        $leagues = array_slice($leagues, 0, $limit);
    }
    ob_start();
    lubowa_shortcode_styles();
    $grid_class = ($limit === 2) ? ' lubowa-grid lubowa-grid-2' : '';
    echo '<div class="lubowa-sc lubowa-leaderboard' . esc_attr($grid_class) . '">';
    foreach ($leagues as $l) {
        $standings = lubowa_get_league_standings($l['id']);
        $top_scorers = $wpdb->get_results($wpdb->prepare(
            "SELECT p.name, p.goals, t.name AS team_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id WHERE t.league_id = %d AND p.goals > 0 ORDER BY p.goals DESC LIMIT 5",
            $l['id']
        ), ARRAY_A);
        echo '<div class="lubowa-card">';
        echo '<h2>' . esc_html($l['name']) . '</h2>';
        echo '<p class="lubowa-league-code">League code: <code>' . esc_html($l['code']) . '</code></p>';
        if (!empty($standings)) {
            echo '<table><thead><tr><th>#</th><th>Team</th><th>P</th><th>W</th><th>D</th><th>L</th><th>GF</th><th>GA</th><th>Pts</th></tr></thead><tbody>';
            $pos = 1;
            foreach ($standings as $s) {
                echo '<tr><td>' . $pos++ . '</td><td>' . esc_html($s['name']) . '</td><td>' . (int) $s['played'] . '</td><td>' . (int) $s['won'] . '</td><td>' . (int) $s['drawn'] . '</td><td>' . (int) $s['lost'] . '</td><td>' . (int) $s['goals_for'] . '</td><td>' . (int) $s['goals_against'] . '</td><td class="lubowa-pts">' . (int) $s['points'] . '</td></tr>';
            }
            echo '</tbody></table>';
        } else {
            echo '<p class="lubowa-empty">No confirmed results yet.</p>';
        }
        if (!empty($top_scorers)) {
            echo '<p style="margin: 1rem 0 0.25rem 0; font-weight: 600; font-size: 0.9rem;">Top scorers</p><ul style="margin: 0; padding-left: 1.2rem; font-size: 0.9rem;">';
            foreach ($top_scorers as $ps) {
                echo '<li>' . esc_html($ps['name']) . ' (' . esc_html($ps['team_name']) . ') – ' . (int) $ps['goals'] . ' goals</li>';
            }
            echo '</ul>';
        }
        echo '</div>';
    }
    if ($view_all_url !== '' && $limit > 0) {
        echo '<p><a href="' . esc_url($view_all_url) . '" class="lubowa-btn">View all leagues</a></p>';
    }
    if ($limit <= 0) {
        $top_all = $wpdb->get_results("SELECT p.name, p.goals, t.name AS team_name, l.name AS league_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id JOIN " . LUBOWA_LEAGUES_TABLE . " l ON t.league_id = l.id WHERE p.goals > 0 ORDER BY p.goals DESC LIMIT 15", ARRAY_A);
        if (!empty($top_all)) {
            echo '<div class="lubowa-card"><h3>Top scorers (all leagues)</h3><table><thead><tr><th>Player</th><th>Team</th><th>League</th><th>Goals</th></tr></thead><tbody>';
            foreach ($top_all as $row) {
                echo '<tr><td>' . esc_html($row['name']) . '</td><td>' . esc_html($row['team_name']) . '</td><td>' . esc_html($row['league_name']) . '</td><td class="lubowa-pts">' . (int) $row['goals'] . '</td></tr>';
            }
            echo '</tbody></table></div>';
        }
    }
    echo '</div>';
    return ob_get_clean();
}

function lubowa_shortcode_top_teams($atts) {
    global $wpdb;
    $atts = shortcode_atts(['limit' => 5], $atts, 'lubowa_top_teams');
    $limit = (int) $atts['limit'];
    if ($limit < 1) {
        $limit = 5;
    }
    $leagues = $wpdb->get_results("SELECT id, name FROM " . LUBOWA_LEAGUES_TABLE . " ORDER BY name", ARRAY_A);
    $leaders = [];
    foreach ($leagues as $l) {
        $standings = lubowa_get_league_standings($l['id']);
        if (!empty($standings)) {
            $first = $standings[0];
            $first['league_name'] = $l['name'];
            $leaders[] = $first;
        }
    }
    usort($leaders, function ($a, $b) { return $b['points'] - $a['points']; });
    $leaders = array_slice($leaders, 0, $limit);
    ob_start();
    lubowa_shortcode_styles();
    echo '<div class="lubowa-sc"><div class="lubowa-card"><h3>Top teams</h3>';
    if (empty($leaders)) {
        echo '<p class="lubowa-empty">No standings yet.</p>';
    } else {
        echo '<div>';
        foreach ($leaders as $i => $t) {
            $pos = $i + 1;
            echo '<div class="lubowa-list-item"><span><span class="lubowa-badge">' . $pos . '</span> ' . esc_html($t['name']) . '</span><span>' . esc_html($t['league_name']) . ' · ' . (int) $t['points'] . ' pts</span></div>';
        }
        echo '</div>';
    }
    echo '</div></div>';
    return ob_get_clean();
}

function lubowa_shortcode_top_players($atts) {
    global $wpdb;
    $atts = shortcode_atts(['limit' => 10], $atts, 'lubowa_top_players');
    $limit = (int) $atts['limit'];
    if ($limit < 1) {
        $limit = 10;
    }
    $rows = $wpdb->get_results($wpdb->prepare(
        "SELECT p.name, p.goals, t.name AS team_name, l.name AS league_name FROM " . LUBOWA_PLAYERS_TABLE . " p JOIN " . LUBOWA_TEAMS_TABLE . " t ON p.team_id = t.id JOIN " . LUBOWA_LEAGUES_TABLE . " l ON t.league_id = l.id WHERE p.goals > 0 ORDER BY p.goals DESC, p.name ASC LIMIT %d",
        $limit
    ), ARRAY_A);
    ob_start();
    lubowa_shortcode_styles();
    echo '<div class="lubowa-sc"><div class="lubowa-card"><h3>Top players</h3>';
    if (empty($rows)) {
        echo '<p class="lubowa-empty">No scorers yet.</p>';
    } else {
        echo '<table><thead><tr><th>#</th><th>Player</th><th>Team</th><th>League</th><th>Goals</th></tr></thead><tbody>';
        foreach ($rows as $i => $row) {
            echo '<tr><td>' . ($i + 1) . '</td><td>' . esc_html($row['name']) . '</td><td>' . esc_html($row['team_name']) . '</td><td>' . esc_html($row['league_name']) . '</td><td class="lubowa-pts">' . (int) $row['goals'] . '</td></tr>';
        }
        echo '</tbody></table>';
    }
    echo '</div></div>';
    return ob_get_clean();
}
