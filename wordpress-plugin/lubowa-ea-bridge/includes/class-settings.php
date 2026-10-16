<?php

if (!defined('ABSPATH')) {
    exit;
}

class Lubowa_EA_Settings {
    const OPTION = 'lubowa_ea_settings';

    public static function defaults() {
        return array(
            'base_url'         => 'https://lubowasportspark.com/appointments/index.php/api/v1',
            'token'            => '',
            'timezone'         => 'Africa/Kampala',
            'slot_step'        => 60,
            'status_pending'   => 'Pending',
            'status_approved'  => 'Approved',
            'intercept_legacy' => 0,
        );
    }

    public static function all() {
        $saved = get_option(self::OPTION, array());
        return array_merge(self::defaults(), is_array($saved) ? $saved : array());
    }

    public static function get($key) {
        $all = self::all();
        return isset($all[$key]) ? $all[$key] : null;
    }

    public static function save(array $values) {
        update_option(self::OPTION, array_merge(self::all(), $values), false);
    }

    public static function timezone() {
        try {
            return new DateTimeZone(self::get('timezone'));
        } catch (Exception $e) {
            return wp_timezone();
        }
    }
}
