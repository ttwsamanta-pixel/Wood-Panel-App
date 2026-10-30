<?php
// Local validation tests; no WordPress database or live submissions are touched.
define('ABSPATH', __DIR__);
class WP_Error { public function __construct(public $code, public $message, public $data) {} }
class WP_REST_Request {
    public function __construct(private array $data) {}
    public function get_body() {return json_encode($this->data);}
    public function get_json_params() {return $this->data;}
}
class WP_REST_Response {
    public function __construct(public $data) {}
    public function header($key,$value) {}
}
function sanitize_text_field($v) {return trim(strip_tags($v));}
function sanitize_email($v) {return filter_var($v,FILTER_SANITIZE_EMAIL);}
function is_email($v) {return filter_var($v,FILTER_VALIDATE_EMAIL);}
function wp_salt($v) {return 'test-salt';}
function get_transient($v) {return 0;}
function set_transient(...$v) {}
function current_time(...$v) {return '2026-10-28 12:00:00';}
class FakeDb {
    public $prefix='test_'; public $queries=[];
    public function prepare($query,...$params) {$this->queries[]=[$query,$params];return $query;}
    public function query($query) {return 1;}
}
$wpdb=new FakeDb();
require __DIR__.'/../wordpress/wood-panel-app-manager/includes/profiles.php';
function check($condition,$label) {if(!$condition)throw new Exception($label);echo "PASS: $label\n";}
$valid=['name'=>'Reader','email'=>'reader@example.com','token'=>str_repeat('a',64),'photo'=>''];
check(wpam_profile_submit(new WP_REST_Request($valid)) instanceof WP_REST_Response,'Valid profile stored');
check($wpdb->queries[0][1][3]===hash('sha256','profile:'.$valid['token']),'Only hashed installation token stored');
foreach (['token'=>'bad','email'=>'bad','name'=>'','photo'=>base64_encode('<script>bad</script>')] as $key=>$value) {
    check(wpam_profile_submit(new WP_REST_Request(array_replace($valid,[$key=>$value]))) instanceof WP_Error, "Reject invalid $key");
}
check(wpam_profile_submit(new WP_REST_Request(array_replace($valid,['photo'=>str_repeat('a',400001)]))) instanceof WP_Error,'Reject oversized request');
check(wpam_csv_cell('=SUM(A1)')==="'=SUM(A1)",'Neutralize CSV formulas');
check(wpam_csv_cell("\t+cmd")==="'\t+cmd",'Neutralize leading whitespace formulas');
check(wpam_csv_cell('Reader')==='Reader','Preserve ordinary CSV text');
check(wpam_submission_kind('profile')==='profile' && wpam_submission_kind('bad')==='newsletter','Allow only known submission kinds');
