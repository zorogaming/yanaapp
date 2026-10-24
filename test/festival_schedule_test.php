<?php
// Run: php test/festival_schedule_test.php (WordPress-independent schedule checks).
define('ABSPATH', __DIR__);
function add_action(...$args) {}
function add_filter(...$args) {}
function wp_timezone() { return new DateTimeZone('Asia/Kolkata'); }
function add_settings_error(...$args) { $GLOBALS['validation_errors'][] = $args; }
function get_option(...$args) { return $GLOBALS['plugin_settings'] ?? []; }
function wp_parse_args($stored, $defaults) { return array_merge($defaults, $stored); }
function sanitize_key($value) { return preg_replace('/[^a-z0-9_\-]/', '', strtolower($value)); }
class WP_REST_Request {
    public function __construct(private array $params) {}
    public function get_param($key) { return $this->params[$key] ?? null; }
}
class WP_REST_Response {
    public function __construct(public array $data, public int $status = 200, public array $headers = []) {}
}
class WP_Query {
    public array $posts = [];
    public int $found_posts = 0;
    public int $max_num_pages = 0;
    public function __construct($args) { $GLOBALS['product_queries'] = ($GLOBALS['product_queries'] ?? 0) + 1; }
}
require __DIR__ . '/../docs/yana_sale_collections_plugin.php';
function check($condition, $message) {
    if (!$condition) throw new RuntimeException($message);
}
function at($date) { return new DateTimeImmutable($date, wp_timezone()); }
$settings = ['festival_schedule_enabled' => 'yes', 'big_days_sale_enabled' => 'no', 'festivals' => [
    'diwali' => ['enabled' => 'yes', 'start' => '2026-11-01T09:00', 'end' => '2026-11-05T21:00'],
    'dhanteras' => ['enabled' => 'yes', 'start' => '2026-11-02T10:00', 'end' => '2026-11-03T10:00'],
]];
$before = Yana_Sale_Collections::festival_state($settings, at('2026-11-01 08:59'));
check(!$before['enabled'] && $before['next_transition_at'] === '2026-11-01T09:00:00+05:30', 'Before start must be closed, with timezone-aware next boundary');
$start = Yana_Sale_Collections::festival_state($settings, at('2026-11-01 09:00'));
check($start['enabled'] && $start['label'] === 'Diwali Sale' && $start['festival_key'] === 'diwali', 'Start is inclusive and auto-enables despite manual toggle');
$overlap = Yana_Sale_Collections::festival_state($settings, at('2026-11-02 10:00'));
check($overlap['festival_key'] === 'dhanteras', 'Latest starting overlapping festival wins');
$return = Yana_Sale_Collections::festival_state($settings, at('2026-11-03 10:00'));
check($return['festival_key'] === 'diwali', 'Previous still-active festival resumes');
$end = Yana_Sale_Collections::festival_state($settings, at('2026-11-05 21:00'));
check(!$end['enabled'] && $end['festival_key'] === '' && $end['next_transition_at'] === null, 'End is exclusive');
$settings['festival_schedule_enabled'] = 'no';
check(!Yana_Sale_Collections::festival_state($settings, at('2026-11-01 09:00'))['enabled'], 'Manual disabled mode preserved');
$settings['big_days_sale_enabled'] = 'yes';
check(Yana_Sale_Collections::festival_state($settings)['label'] === 'Big Days Sale', 'Manual generic sale preserved');
$invalid = Yana_Sale_Collections::sanitize_settings(['festival_schedule_enabled'=>'yes', 'festivals'=>[
    'diwali'=>['enabled'=>'yes','start'=>'2026-02-30T09:00','end'=>'2026-03-02T09:00'],
    'holi'=>['enabled'=>'yes','start'=>'2026-03-02T09:00','end'=>'2026-03-01T09:00'],
]]);
check($invalid['festivals']['diwali']['enabled']==='no' && $invalid['festivals']['holi']['enabled']==='no', 'Invalid and reversed dates must be disabled');
check(count($GLOBALS['validation_errors']) === 2, 'Invalid dates show admin errors');
foreach (Yana_Sale_Collections::festival_catalog() as $key => $label) {
    $config=['festival_schedule_enabled'=>'yes','festivals'=>[$key=>['enabled'=>'yes','start'=>'2026-01-01T00:00','end'=>'2027-01-01T00:00']]];
    $state=Yana_Sale_Collections::festival_state($config, at('2026-06-01'));
    check($state['enabled'] && $state['festival_key']===$key && str_ends_with($state['label'],' Sale'), 'All festivals must have a valid active name: '.$key);
}
$now = new DateTimeImmutable('now', wp_timezone());
$GLOBALS['plugin_settings'] = ['festival_schedule_enabled'=>'yes', 'festivals'=>[
    'diwali'=>['enabled'=>'yes','start'=>$now->modify('-1 day')->format('Y-m-d\TH:i'), 'end'=>$now->modify('+1 day')->format('Y-m-d\TH:i')],
]];
$response = Yana_Sale_Collections::get_sale_collection(new WP_REST_Request(['type'=>'big_days_sale','status_only'=>'1']));
check($response->data['enabled'] && $response->data['label']==='Diwali Sale', 'REST status returns scheduled name');
check(($GLOBALS['product_queries'] ?? 0)===0, 'Status-only must not query products');
check($response->headers['Cache-Control']==='no-store, max-age=0', 'Schedule status must not be cached');
$collection = Yana_Sale_Collections::get_sale_collection(new WP_REST_Request(['type'=>'big_days_sale','per_page'=>20]));
check($collection->data['label']==='Diwali Sale' && $collection->data['items']===[], 'Product endpoint includes festival metadata');
$GLOBALS['plugin_settings']['festivals']['diwali']['enabled']='no';
$closed = Yana_Sale_Collections::get_sale_collection(new WP_REST_Request(['type'=>'big_days_sale']));
check(!$closed->data['enabled'] && $closed->data['items']===[], 'Closed schedule returns no sale products');
$bad = Yana_Sale_Collections::get_sale_collection(new WP_REST_Request(['type'=>'invalid']));
check($bad->status===400, 'Unknown collection rejected');
echo "Festival checks passed: 22 festivals, boundaries, overlaps, validation, manual mode, REST status/products/cache headers.\n";
