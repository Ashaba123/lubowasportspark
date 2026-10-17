<?php

if (!defined('ABSPATH')) {
    exit;
}

class Lubowa_EA_Admin {
    const SLUG = 'lubowa-ea-bridge';
    const MIGRATED_OPTION = 'lubowa_ea_migrated';

    public static function init() {
        add_action('admin_menu', array(__CLASS__, 'menu'));
        add_action('admin_post_lubowa_ea_save', array(__CLASS__, 'handle_save'));
        add_action('admin_post_lubowa_ea_migrate', array(__CLASS__, 'handle_migrate'));
    }

    public static function menu() {
        add_options_page('Lubowa EA Bridge', 'Lubowa EA Bridge', 'manage_options', self::SLUG, array(__CLASS__, 'render'));
    }

    public static function handle_save() {
        if (!current_user_can('manage_options')) {
            wp_die('Forbidden', 403);
        }
        check_admin_referer('lubowa_ea_save');

        $values = array(
            'base_url'         => esc_url_raw(wp_unslash($_POST['base_url'] ?? '')),
            'timezone'         => sanitize_text_field(wp_unslash($_POST['timezone'] ?? '')),
            'slot_step'        => max(5, (int) ($_POST['slot_step'] ?? 60)),
            'status_pending'   => sanitize_text_field(wp_unslash($_POST['status_pending'] ?? '')),
            'status_approved'  => sanitize_text_field(wp_unslash($_POST['status_approved'] ?? '')),
            'status_hold'      => sanitize_text_field(wp_unslash($_POST['status_hold'] ?? '')),
            'hold_minutes'     => max(1, (int) ($_POST['hold_minutes'] ?? 5)),
            'intercept_legacy' => empty($_POST['intercept_legacy']) ? 0 : 1,
        );
        $token = trim(wp_unslash($_POST['token'] ?? ''));
        if ($token !== '') {
            $values['token'] = sanitize_text_field($token);
        }

        Lubowa_EA_Settings::save($values);
        Lubowa_EA_Client::flush_cache();
        wp_safe_redirect(add_query_arg(array('page' => self::SLUG, 'saved' => 1), admin_url('options-general.php')));
        exit;
    }

    public static function handle_migrate() {
        if (!current_user_can('manage_options')) {
            wp_die('Forbidden', 403);
        }
        check_admin_referer('lubowa_ea_migrate');

        $report = self::migrate();
        set_transient('lubowa_ea_migration_report_' . get_current_user_id(), $report, 600);
        wp_safe_redirect(add_query_arg(array('page' => self::SLUG, 'migrated' => 1), admin_url('options-general.php')));
        exit;
    }

    public static function render() {
        if (!current_user_can('manage_options')) {
            return;
        }
        $s = Lubowa_EA_Settings::all();
        $report = isset($_GET['migrated']) ? get_transient('lubowa_ea_migration_report_' . get_current_user_id()) : null;
        $legacy_table = self::legacy_table();
        ?>
        <div class="wrap">
            <h1>Lubowa EA Bridge</h1>

            <?php if (isset($_GET['saved'])) : ?>
                <div class="notice notice-success"><p>Settings saved.</p></div>
            <?php endif; ?>

            <h2>Connection</h2>
            <?php self::render_connection_status(); ?>

            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
                <input type="hidden" name="action" value="lubowa_ea_save">
                <?php wp_nonce_field('lubowa_ea_save'); ?>
                <table class="form-table" role="presentation">
                    <tr>
                        <th scope="row"><label for="base_url">EA API base URL</label></th>
                        <td><input name="base_url" id="base_url" type="url" class="regular-text" value="<?php echo esc_attr($s['base_url']); ?>"></td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="token">EA API token</label></th>
                        <td>
                            <input name="token" id="token" type="password" class="regular-text" autocomplete="new-password" placeholder="<?php echo $s['token'] !== '' ? esc_attr('Saved — leave blank to keep') : ''; ?>">
                            <p class="description">From Easy!Appointments → Settings → Integrations → API.</p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="timezone">Timezone</label></th>
                        <td><input name="timezone" id="timezone" type="text" value="<?php echo esc_attr($s['timezone']); ?>"></td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="slot_step">Slot grid step (minutes)</label></th>
                        <td><input name="slot_step" id="slot_step" type="number" min="5" step="5" value="<?php echo esc_attr($s['slot_step']); ?>"></td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="status_pending">New booking status</label></th>
                        <td><input name="status_pending" id="status_pending" type="text" value="<?php echo esc_attr($s['status_pending']); ?>">
                            <p class="description">Must match a status in EA → Settings → Business Logic → Appointment Status Options.</p></td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="status_approved">Approved status</label></th>
                        <td><input name="status_approved" id="status_approved" type="text" value="<?php echo esc_attr($s['status_approved']); ?>">
                            <p class="description">Used when migrating legacy approved bookings.</p></td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="status_hold">Hold status</label></th>
                        <td><input name="status_hold" id="status_hold" type="text" value="<?php echo esc_attr($s['status_hold']); ?>">
                            <p class="description">Placeholder appointment while an app user fills in details. Must match a status in EA → Settings → Business Logic → Appointment Status Options.</p></td>
                    </tr>
                    <tr>
                        <th scope="row"><label for="hold_minutes">Hold length (minutes)</label></th>
                        <td><input name="hold_minutes" id="hold_minutes" type="number" min="1" value="<?php echo esc_attr($s['hold_minutes']); ?>"></td>
                    </tr>
                    <tr>
                        <th scope="row">Legacy app routes</th>
                        <td><label><input name="intercept_legacy" type="checkbox" value="1" <?php checked((int) $s['intercept_legacy'], 1); ?>>
                            Send old app builds' <code>POST /lubowa/v1/bookings</code> and <code>/bookings/slots</code> to EA</label></td>
                    </tr>
                </table>
                <?php submit_button('Save settings'); ?>
            </form>

            <h2>Migrate legacy bookings</h2>
            <?php if ($legacy_table === null) : ?>
                <p>No legacy Lubowa bookings table found.</p>
            <?php else : ?>
                <p>Copies future, non-cancelled bookings from <code><?php echo esc_html($legacy_table); ?></code> into EA. Already-migrated rows are skipped, so it is safe to run again. The legacy table is not changed.</p>
                <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
                    <input type="hidden" name="action" value="lubowa_ea_migrate">
                    <?php wp_nonce_field('lubowa_ea_migrate'); ?>
                    <?php submit_button('Migrate future bookings to EA', 'secondary'); ?>
                </form>
            <?php endif; ?>

            <?php if (is_array($report)) : ?>
                <h3>Migration report</h3>
                <table class="widefat striped">
                    <thead><tr><th>Legacy ID</th><th>Date</th><th>Time</th><th>Service</th><th>Result</th></tr></thead>
                    <tbody>
                    <?php if (empty($report)) : ?>
                        <tr><td colspan="5">Nothing to migrate.</td></tr>
                    <?php endif; ?>
                    <?php foreach ($report as $row) : ?>
                        <tr>
                            <td><?php echo esc_html($row['id']); ?></td>
                            <td><?php echo esc_html($row['date']); ?></td>
                            <td><?php echo esc_html($row['time']); ?></td>
                            <td><?php echo esc_html($row['service']); ?></td>
                            <td><?php echo esc_html($row['result']); ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
        <?php
    }

    private static function render_connection_status() {
        if (Lubowa_EA_Settings::get('token') === '') {
            echo '<p>Not configured. Save the EA API token below.</p>';
            return;
        }
        $services = Lubowa_EA_Booking_Service::list_services();
        if (is_wp_error($services)) {
            echo '<div class="notice notice-error inline"><p>' . esc_html($services->get_error_message()) . '</p></div>';
            return;
        }
        $pitch = Lubowa_EA_Booking_Service::pitch_check();
        if (is_wp_error($pitch)) {
            echo '<div class="notice notice-error inline"><p>' . esc_html($pitch->get_error_message()) . '</p></div>';
        }
        echo '<p>Connected. Bookable services (with a provider):</p><ul>';
        foreach ($services as $service) {
            echo '<li>' . esc_html(sprintf('#%d %s — %d min', $service['id'], $service['name'], $service['duration'])) . '</li>';
        }
        echo '</ul>';
        if (empty($services)) {
            echo '<p>No services are linked to a provider yet.</p>';
        }
    }

    private static function legacy_table() {
        global $wpdb;
        $like = $wpdb->esc_like($wpdb->prefix . 'lubowa') . '%' . $wpdb->esc_like('booking') . '%';
        $tables = $wpdb->get_col($wpdb->prepare('SHOW TABLES LIKE %s', $like));
        foreach ((array) $tables as $table) {
            if ($table === $wpdb->prefix . 'lubowa_ea_league_bookings') {
                continue;
            }
            $columns = $wpdb->get_col("SHOW COLUMNS FROM `" . esc_sql($table) . "`");
            if (in_array('date', $columns, true) && in_array('time_slot', $columns, true)) {
                return $table;
            }
        }
        return null;
    }

    private static function migrate() {
        global $wpdb;
        $table = self::legacy_table();
        if ($table === null) {
            return array();
        }

        $today = (new DateTime('today', Lubowa_EA_Settings::timezone()))->format('Y-m-d');
        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT * FROM `" . esc_sql($table) . "` WHERE `date` >= %s ORDER BY `date`, `time_slot`",
            $today
        ), ARRAY_A);

        $migrated = get_option(self::MIGRATED_OPTION, array());
        if (!is_array($migrated)) {
            $migrated = array();
        }
        $report = array();

        foreach ((array) $rows as $row) {
            $id = (int) $row['id'];
            $status = strtolower(trim((string) ($row['status'] ?? 'pending')));
            $service_name = (string) ($row['service'] ?? '');
            $line = array('id' => $id, 'date' => $row['date'], 'time' => $row['time_slot'], 'service' => $service_name);

            if (isset($migrated[$id])) {
                $report[] = $line + array('result' => 'Already migrated (EA #' . (int) $migrated[$id] . ')');
                continue;
            }
            if (in_array($status, array('cancelled', 'canceled', 'rejected', 'declined'), true)) {
                $report[] = $line + array('result' => 'Skipped: ' . $status);
                continue;
            }
            $time = self::normalize_time((string) $row['time_slot']);
            if ($time === null) {
                $report[] = $line + array('result' => 'Skipped: unreadable time');
                continue;
            }
            $service = Lubowa_EA_Booking_Service::find_service_by_name($service_name);
            if (is_wp_error($service)) {
                $report[] = $line + array('result' => 'Skipped: no EA service named "' . $service_name . '"');
                continue;
            }

            $ea_status = $status === 'approved'
                ? Lubowa_EA_Settings::get('status_approved')
                : Lubowa_EA_Settings::get('status_pending');
            $notes = trim('Migrated from app booking #' . $id . '. ' . (string) ($row['notes'] ?? ''));

            $created = Lubowa_EA_Booking_Service::book(
                (int) $service['id'],
                array((string) $row['date']),
                $time,
                array(
                    'name'  => (string) ($row['contact_name'] ?? ''),
                    'email' => (string) ($row['contact_email'] ?? ''),
                    'phone' => (string) ($row['contact_phone'] ?? ''),
                ),
                $notes,
                $ea_status
            );

            if (is_wp_error($created)) {
                $report[] = $line + array('result' => 'Failed: ' . $created->get_error_message());
                continue;
            }

            $migrated[$id] = (int) $created[0]['id'];
            update_option(self::MIGRATED_OPTION, $migrated, false);
            $report[] = $line + array('result' => 'Migrated → EA #' . (int) $created[0]['id']);
        }

        return $report;
    }

    /** Accepts "10:00", "10:00:00", "10am", "4pm", "4:30 pm". */
    private static function normalize_time($raw) {
        $raw = strtolower(trim($raw));
        if (preg_match('/^(\d{1,2}):(\d{2})(?::\d{2})?$/', $raw, $m)) {
            return sprintf('%02d:%02d', (int) $m[1], (int) $m[2]);
        }
        if (preg_match('/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$/', $raw, $m)) {
            $hour = (int) $m[1] % 12 + ($m[3] === 'pm' ? 12 : 0);
            return sprintf('%02d:%02d', $hour, isset($m[2]) && $m[2] !== '' ? (int) $m[2] : 0);
        }
        return null;
    }
}
