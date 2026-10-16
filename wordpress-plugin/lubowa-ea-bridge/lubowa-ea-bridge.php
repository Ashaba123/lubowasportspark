<?php
/**
 * Plugin Name: Lubowa EA Bridge
 * Description: Routes Lubowa Sports Park app bookings into Easy!Appointments. Adds /lubowa-ea/v1 REST endpoints (services, slots, bookings, league bookings), optionally intercepts the legacy /lubowa/v1/bookings routes, and migrates future legacy bookings into EA.
 * Version: 1.0.1
 * Author: Ashaba Derrick
 * Requires PHP: 7.4
 */

if (!defined('ABSPATH')) {
    exit;
}

define('LUBOWA_EA_VERSION', '1.0.1');
define('LUBOWA_EA_DIR', plugin_dir_path(__FILE__));

require_once LUBOWA_EA_DIR . 'includes/class-settings.php';
require_once LUBOWA_EA_DIR . 'includes/class-ea-client.php';
require_once LUBOWA_EA_DIR . 'includes/class-booking-service.php';
require_once LUBOWA_EA_DIR . 'includes/class-rest.php';
require_once LUBOWA_EA_DIR . 'includes/class-admin.php';

register_activation_hook(__FILE__, 'lubowa_ea_activate');

function lubowa_ea_activate() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $table = $wpdb->prefix . 'lubowa_ea_league_bookings';
    $charset = $wpdb->get_charset_collate();
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
}

add_action('rest_api_init', array('Lubowa_EA_Rest', 'register_routes'));
add_filter('rest_pre_dispatch', array('Lubowa_EA_Rest', 'intercept_legacy'), 10, 3);

if (is_admin()) {
    Lubowa_EA_Admin::init();
}
