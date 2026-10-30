<?php
// Local UI fixture, never loaded by the WordPress plugin.
require __DIR__ . '/settings-test.php';
function current_user_can($capability) { return true; }
function get_terms($args) { return array_map(static fn($i) => (object) ['term_id' => $i, 'name' => ['Hot Products', 'Woodworking News', 'Events', 'Machinery', 'Sustainability'][$i - 1]], range(1, 5)); }
function is_wp_error($value) { return false; }
function esc_attr($value) { return htmlspecialchars((string) $value, ENT_QUOTES); }
function esc_html($value) { return esc_attr($value); }
function esc_url($value) { return esc_attr($value); }
function esc_textarea($value) { return esc_attr($value); }
function checked($a, $b, $echo = true) { $s = $a == $b ? 'checked' : ''; if ($echo) echo $s; return $s; }
function selected($a, $b) { if ($a == $b) echo 'selected'; }
function settings_errors() {}
function settings_fields($group) { echo '<input type="hidden" name="option_page" value="wpam">'; }
function rest_url($path) { return home_url('/wp-json/' . $path); }
function get_post_types($args, $output) { return [(object) ['name' => 'magazine', 'label' => 'Magazine Archive'], (object) ['name' => 'tribe_events', 'label' => 'Events']]; }
function wp_json_encode($value, $flags = 0) { return json_encode($value, $flags); }
function submit_button($label) { echo '<p class="submit"><button type="submit" class="button button-primary">' . esc_html($label) . '</button></p>'; }
require __DIR__ . '/../wood-panel-app-manager/includes/admin.php';
?><!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>App Settings Preview</title>
<style>body{background:#f0f0f1;font-family:Arial,sans-serif;margin:24px}input,button,select,textarea{font:inherit}input{padding:6px}.form-table{width:100%;text-align:left}.button{padding:7px 12px;border:1px solid #9babb5;border-radius:4px;background:white;cursor:pointer}.regular-text{width:350px}.large-text{width:100%;box-sizing:border-box}.notice{padding:12px;background:#fff8e5}*{box-sizing:border-box}</style>
<link rel="stylesheet" href="../../wordpress/wood-panel-app-manager/assets/admin.css"></head><body>
<?php wpam_admin_page(); ?>
<script>window.wp={media:()=>({on:()=>{},open:()=>{window.mediaOpened=true}})};</script>
<script src="../../wordpress/wood-panel-app-manager/assets/admin.js"></script></body></html>
