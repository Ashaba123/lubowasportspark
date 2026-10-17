<?php
/**
 * Plugin Name: Lubowa EA Bridge
 * Description: Routes Lubowa Sports Park app bookings into Easy!Appointments. Adds /lubowa-ea/v1 REST endpoints (services, slots, slot holds, guest and account bookings, league bookings), optionally intercepts the legacy /lubowa/v1/bookings routes, and migrates future legacy bookings into EA.
 * Version: 1.1.1
 * Author: Ashaba Derrick
 * Requires PHP: 7.4
 */

if (!defined('ABSPATH')) {
    exit;
}

define('LUBOWA_EA_VERSION', '1.1.1');
define('LUBOWA_EA_DIR', plugin_dir_path(__FILE__));

require_once LUBOWA_EA_DIR . 'includes/class-settings.php';
require_once LUBOWA_EA_DIR . 'includes/class-ea-client.php';
require_once LUBOWA_EA_DIR . 'includes/class-booking-service.php';
require_once LUBOWA_EA_DIR . 'includes/class-holds.php';
require_once LUBOWA_EA_DIR . 'includes/class-rest.php';
require_once LUBOWA_EA_DIR . 'includes/class-admin.php';

register_activation_hook(__FILE__, 'lubowa_ea_activate');
register_deactivation_hook(__FILE__, 'lubowa_ea_deactivate');

function lubowa_ea_activate() {
    lubowa_ea_install();
}

function lubowa_ea_deactivate() {
    wp_clear_scheduled_hook('lubowa_ea_purge_holds');
}

function lubowa_ea_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $charset = $wpdb->get_charset_collate();

    $table = $wpdb->prefix . 'lubowa_ea_league_bookings';
    dbDelta("CREATE TABLE $table (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        league_id bigint(20) unsigned NOT NULL,
        ea_appointment_id bigint(20) unsigned NOT NULL,
        start_datetime datetime NOT NULL,
        created_by bigint(20) unsigned NOT NULL,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY league_id (league_id)
    ) $charset;");

    $table = $wpdb->prefix . 'lubowa_ea_holds';
    dbDelta("CREATE TABLE $table (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        device_hash char(64) NOT NULL,
        ea_appointment_id bigint(20) unsigned NOT NULL,
        provider_id bigint(20) unsigned NOT NULL,
        service_id bigint(20) unsigned NOT NULL,
        start_datetime datetime NOT NULL,
        expires_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY device_hash (device_hash),
        KEY expires_at (expires_at)
    ) $charset;");

    $table = $wpdb->prefix . 'lubowa_ea_guest_tokens';
    dbDelta("CREATE TABLE $table (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        token_hash char(64) NOT NULL,
        ea_appointment_id bigint(20) unsigned NOT NULL,
        service_id bigint(20) unsigned NOT NULL,
        start_datetime datetime NOT NULL,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY token_hash (token_hash)
    ) $charset;");

    if (!wp_next_scheduled('lubowa_ea_purge_holds')) {
        wp_schedule_event(time(), 'lubowa_ea_five_minutes', 'lubowa_ea_purge_holds');
    }
    update_option('lubowa_ea_db_version', LUBOWA_EA_VERSION, false);
}

// Plugin updates by file upload do not re-run activation.
add_action('plugins_loaded', function () {
    if (get_option('lubowa_ea_db_version') !== LUBOWA_EA_VERSION) {
        lubowa_ea_install();
    }
});

add_filter('cron_schedules', function ($schedules) {
    $schedules['lubowa_ea_five_minutes'] = array('interval' => 300, 'display' => 'Every 5 minutes');
    return $schedules;
});
add_action('lubowa_ea_purge_holds', array('Lubowa_EA_Holds', 'purge_expired'));

add_action('rest_api_init', array('Lubowa_EA_Rest', 'register_routes'));
add_filter('rest_pre_dispatch', array('Lubowa_EA_Rest', 'intercept_legacy'), 10, 3);

if (is_admin()) {
    Lubowa_EA_Admin::init();
}
