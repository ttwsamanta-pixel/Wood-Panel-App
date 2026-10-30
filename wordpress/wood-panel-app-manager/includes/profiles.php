<?php
defined('ABSPATH') || exit;

function wpam_profile_upgrade(): void {
    if (get_option('wpam_profile_schema') === '1') return;
    wpam_activate();
    global $wpdb;
    if ($wpdb->get_var("SHOW COLUMNS FROM {$wpdb->prefix}wpam_submissions LIKE 'photo'")) update_option('wpam_profile_schema', '1', false);
}

function wpam_profile_submit(WP_REST_Request $request) {
    global $wpdb;
    if (strlen($request->get_body()) > 400000) return new WP_Error('too_large', 'Choose a smaller photo.', ['status'=>413]);
    $data = $request->get_json_params();
    if (!is_array($data)) return new WP_Error('invalid', 'Invalid profile.', ['status'=>422]);
    foreach (['name','email','photo','token'] as $field) if (!is_string($data[$field] ?? '')) return new WP_Error('invalid', 'Invalid profile.', ['status'=>422]);
    $name = sanitize_text_field($data['name'] ?? '');
    $email = sanitize_email($data['email'] ?? '');
    $token = $data['token'] ?? '';
    if (!$name || strlen($name)>160 || !is_email($email) || strlen($email)>254 || !preg_match('/^[a-f0-9]{64}$/D', $token)) return new WP_Error('invalid', 'Enter a valid name and email.', ['status'=>422]);
    $rate_key = 'wpam_profile_rate_' . hash_hmac('sha256', (string)($_SERVER['REMOTE_ADDR'] ?? ''), wp_salt('nonce'));
    $rate = (int)get_transient($rate_key);
    if ($rate >= 20) return new WP_Error('rate_limited', 'Please try again later.', ['status'=>429]);
    set_transient($rate_key, $rate+1, 600);
    $photo = '';
    if (!empty($data['photo'])) {
        $bytes = base64_decode($data['photo'], true);
        $info = $bytes === false ? false : @getimagesizefromstring($bytes);
        if (!$info || strlen($bytes)>250000 || $info[0]>1024 || $info[1]>1024 || !in_array($info['mime'], ['image/jpeg','image/png','image/webp'], true)) return new WP_Error('invalid_photo', 'Use a small JPG, PNG or WebP photo.', ['status'=>422]);
        $photo = 'data:' . $info['mime'] . ';base64,' . base64_encode($bytes);
    }
    // Only the private random installation token can update its own record.
    $key = hash('sha256', 'profile:' . $token);
    $table = $wpdb->prefix . 'wpam_submissions';
    $result = $wpdb->query($wpdb->prepare("INSERT INTO $table (kind,email,name,country,subject,message,photo,submission_key,created_at) VALUES ('profile',%s,%s,'','','',%s,%s,%s) ON DUPLICATE KEY UPDATE name=VALUES(name),email=VALUES(email),photo=VALUES(photo)", $email,$name,$photo,$key,current_time('mysql',true)));
    if ($result === false) return new WP_Error('storage_error','Could not save your profile. Please try again.', ['status'=>500]);
    $response = new WP_REST_Response(['success'=>true]);
    $response->header('Cache-Control', 'no-store');
    return $response;
}

function wpam_submission_kind($value): string {
    return in_array($value, ['newsletter','contact','profile'], true) ? $value : 'newsletter';
}

function wpam_csv_cell($value): string {
    $text = (string)$value;
    return preg_match('/^[\s]*[=+@-]/', $text) ? "'" . $text : $text;
}

function wpam_submission_action(): void {
    if (!current_user_can('manage_options')) wp_die('Not allowed.', '', ['response'=>403]);
    check_admin_referer('wpam_submission_action');
    global $wpdb;
    $kind = wpam_submission_kind($_POST['kind'] ?? '');
    $action = sanitize_key($_POST['operation'] ?? '');
    $ids = array_slice(array_filter(array_map('absint', (array)($_POST['ids'] ?? []))), 0, 1000);
    $where = $wpdb->prepare('kind=%s', $kind);
    if ($ids) $where .= ' AND id IN (' . implode(',', $ids) . ')';
    $table = $wpdb->prefix . 'wpam_submissions';
    if ($action === 'delete' && $ids) $wpdb->query("DELETE FROM $table WHERE $where");
    if ($action === 'csv') {
        nocache_headers();
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="app-' . $kind . '.csv"');
        $out = fopen('php://output','w');
        fputcsv($out,['ID','Received UTC','Name','Email','Country','Subject','Message','Photo supplied'], ',', '"', '');
        $last = 0;
        do {
            $rows=$wpdb->get_results("SELECT id,created_at,name,email,country,subject,message,(photo IS NOT NULL AND photo <> '') AS has_photo FROM $table WHERE $where AND id > $last ORDER BY id LIMIT 500");
            foreach ($rows as $row) { $last=(int)$row->id; fputcsv($out,array_map('wpam_csv_cell',[(string)$row->id,$row->created_at,$row->name,$row->email,$row->country,$row->subject,$row->message,$row->has_photo ? 'Yes':'No']), ',', '"', ''); }
        } while (count($rows) === 500);
        fclose($out); exit;
    }
    wp_safe_redirect(admin_url('admin.php?page=wpam-submissions&kind=' . $kind)); exit;
}

function wpam_profiles_page(): void { wpam_submissions_page('profile'); }

function wpam_submissions_page($fixed_kind = ''): void {
    if (!current_user_can('manage_options')) return;
    global $wpdb;
    $kind=wpam_submission_kind($fixed_kind ?: ($_GET['kind'] ?? ''));
    $page=max(1,absint($_GET['paged'] ?? 1));
    $table=$wpdb->prefix . 'wpam_submissions';
    $count=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $table WHERE kind=%s",$kind));
    $rows=$wpdb->get_results($wpdb->prepare("SELECT * FROM $table WHERE kind=%s ORDER BY id DESC LIMIT 25 OFFSET %d",$kind,($page-1)*25));
    echo '<div class="wrap"><h1>App ' . ($kind === 'profile' ? 'Profiles':'Submissions') . '</h1><p class="wpam-submission-tabs">';
    foreach (['newsletter','contact','profile'] as $tab) echo '<a style="margin-right:16px" href="' . esc_url(admin_url('admin.php?page=wpam-submissions&kind='.$tab)) . '">' . esc_html(ucfirst($tab)) . '</a>';
    echo '</p><p>CSV exports selected rows, or all records when nothing is selected. Photos remain private in this admin page; CSV records whether a photo was supplied.</p><form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
    wp_nonce_field('wpam_submission_action');
    echo '<input type="hidden" name="action" value="wpam_submission_action"><input type="hidden" name="kind" value="' . esc_attr($kind) . '"><p><button class="button" name="operation" value="csv">Download CSV</button> <button class="button" name="operation" value="delete" onclick="return confirm(\'Delete selected records permanently?\')">Delete selected</button></p><table class="widefat striped"><thead><tr><th><input type="checkbox" aria-label="Select all rows" onclick="this.closest(\'table\').querySelectorAll(\'input[name=&quot;ids[]&quot;]\').forEach(x=>x.checked=this.checked)"></th><th>Received UTC</th><th>Name / Photo</th><th>Email</th><th>Country</th><th>Subject / Message</th></tr></thead><tbody>';
    foreach ($rows as $row) {
        echo '<tr><td><input type="checkbox" name="ids[]" aria-label="Select record ' . (int)$row->id . '" value="' . (int)$row->id . '"></td><td>' . esc_html($row->created_at) . '</td><td>' . esc_html($row->name);
        if ($kind === 'profile' && preg_match('~^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$~D', (string)$row->photo)) echo '<br><img width="64" height="64" style="object-fit:cover;border-radius:50%" alt="Profile photo" src="' . esc_attr($row->photo) . '">';
        echo '</td><td>' . esc_html($row->email) . '</td><td>' . esc_html($row->country) . '</td><td>' . esc_html($row->subject) . '<br>' . nl2br(esc_html($row->message)) . '</td></tr>';
    }
    if (!$rows) echo '<tr><td colspan="6">No submissions.</td></tr>';
    echo '</tbody></table></form>';
    echo wp_kses_post((string)paginate_links(['base'=>add_query_arg('paged','%#%'),'format'=>'','current'=>$page,'total'=>max(1,(int)ceil($count/25))]));
    echo '</div>';
}
