<?php
/**
 * Plugin Name: Yana Sale Banners
 * Description: App-style Daily Sale and Big Days Sale banners with product collections from the Yana sale API.
 * Version: 1.3.1
 * Author: Yana Worldwide
 */
if (!defined('ABSPATH')) { exit; }

function yana_sale_collection_data($type, $page = 1, $per_page = 50, $status_only = false) {
    if (!function_exists('rest_do_request')) return array();
    $request = new WP_REST_Request('GET', '/wp/v1/sale-collection');
    $request->set_param('type', sanitize_key($type));
    $request->set_param('page', max(1, absint($page)));
    $request->set_param('per_page', max(1, min(50, absint($per_page))));
    if ($status_only) $request->set_param('status_only', 1);
    $response = rest_do_request($request);
    if (is_wp_error($response) || !($response instanceof WP_REST_Response) || $response->get_status() >= 400) return array();
    $data = $response->get_data();
    return is_array($data) ? $data : array();
}

function yana_sale_banner_front_assets() {
    if (did_action('elementor/loaded') && class_exists('\\Elementor\\Plugin')) {
        $elementor = \Elementor\Plugin::$instance;
        if (isset($elementor->editor) && method_exists($elementor->editor, 'is_edit_mode') && $elementor->editor->is_edit_mode()) return;
        if (isset($elementor->preview) && method_exists($elementor->preview, 'is_preview_mode') && $elementor->preview->is_preview_mode()) return;
    }
    $sale_page = in_array(sanitize_key(get_query_var('yana_sale')), array('daily_sale', 'big_days_sale'), true);
    if (!is_front_page() && !$sale_page) return;
    $base = plugin_dir_url(__FILE__);
    wp_enqueue_style('yana-sale-banners', $base . 'assets/banners.css', array(), '1.3.1');
    if (!$sale_page) wp_enqueue_style('yana-homepage-refresh', $base . 'assets/homepage.css', array('yana-sale-banners'), '1.0.0');
    if ($sale_page) return;
    wp_enqueue_script('yana-sale-banners', $base . 'assets/banners.js', array(), '1.3.0', true);
    $daily = yana_sale_collection_data('daily_sale', 1, 1, true);
    $big = yana_sale_collection_data('big_days_sale', 1, 1, true);
    wp_localize_script('yana-sale-banners', 'YanaSaleBanners', array(
        'dailyUrl' => add_query_arg('yana_sale', 'daily_sale', home_url('/')),
        'bigDaysUrl' => add_query_arg('yana_sale', 'big_days_sale', home_url('/')),
        'dailyEnabled' => !empty($daily['enabled']),
        'bigDaysEnabled' => !empty($big['enabled']),
        'bigDaysLabel' => sanitize_text_field($big['label'] ?? 'Big Days Sale'),
        'upcomingLabel' => sanitize_text_field($big['upcoming_label'] ?? ''),
        'upcomingMessage' => !empty($big['upcoming_label']) && !empty($big['upcoming_starts_at']) ? sanitize_text_field($big['upcoming_label'] . ' starts ' . wp_date('M j', strtotime($big['upcoming_starts_at']))) : '',
        'upcomingMessage' => !empty($big['upcoming_label']) && !empty($big['upcoming_starts_at']) ? sanitize_text_field($big['upcoming_label'] . ' starts ' . wp_date('M j', strtotime($big['upcoming_starts_at']))) : '',
        'helmet' => $base . 'assets/helmet.jpg',
        'jacket' => $base . 'assets/jacket.jpg',
    ));
}
add_action('wp_enqueue_scripts', 'yana_sale_banner_front_assets');

function yana_sale_banner_query_vars($vars) {
    $vars[] = 'yana_sale';
    $vars[] = 'yana_sale_page';
    return $vars;
}
add_filter('query_vars', 'yana_sale_banner_query_vars');

function yana_sale_banner_collection_page() {
    $type = sanitize_key(get_query_var('yana_sale'));
    if (!in_array($type, array('daily_sale', 'big_days_sale'), true)) return;
    if (!function_exists('wc_get_product')) {
        status_header(503);
        wp_die(esc_html__('The product catalog is temporarily unavailable.', 'yana-sale-banners'));
    }
    $page = max(1, absint(get_query_var('yana_sale_page')));
    $data = yana_sale_collection_data($type, $page, 50, false);
    $enabled = !empty($data['enabled']);
    $title = sanitize_text_field($data['label'] ?? ($type === 'daily_sale' ? 'Daily Sale' : 'Big Days Sale'));
    $items = !empty($data['items']) && is_array($data['items']) ? $data['items'] : array();
    $total_pages = max(1, absint($data['pages'] ?? 1));
    status_header(200);
    get_header();
    ?>
    <main class="yana-sale-archive">
      <div class="yana-sale-archive-top">
        <a class="yana-sale-back" href="<?php echo esc_url(home_url('/')); ?>" aria-label="Back to homepage">←</a>
        <div><span class="yana-sale-eyebrow">YANAWORLDWIDE • EXCLUSIVE OFFERS</span><h1><?php echo esc_html($title); ?></h1></div>
      </div>
      <?php if ($type === 'big_days_sale' && !$enabled): ?>
        <section class="yana-sale-empty"><span class="yana-sale-empty-icon">✦</span><h2><?php echo esc_html($data['upcoming_label'] ?? 'Big Days Sale'); ?></h2><p><?php echo esc_html($data['message'] ?? 'This sale is coming soon.'); ?></p><span class="yana-sale-status">COMING SOON</span></section>
      <?php elseif (!$enabled): ?>
        <section class="yana-sale-empty"><span class="yana-sale-empty-icon">ϟ</span><h2>Sale is currently unavailable</h2><p>Please check back during the next sale window.</p><span class="yana-sale-status">CLOSED</span></section>
      <?php elseif (!$items): ?>
        <section class="yana-sale-empty"><span class="yana-sale-empty-icon">✦</span><h2>No products in this sale yet</h2><p>Please check back shortly.</p></section>
      <?php else: ?>
        <div class="yana-sale-archive-summary"><span><?php echo esc_html(number_format_i18n(absint($data['total'] ?? count($items)))); ?> selected deals</span><span><?php echo esc_html($type === 'daily_sale' ? 'Daily Sale' : 'Big Days Sale'); ?></span></div>
        <div class="yana-sale-products">
          <?php foreach ($items as $item):
            $product = wc_get_product(absint($item['id'] ?? 0));
            if (!$product || !$product->exists()) continue;
            $product_url = get_permalink($product->get_id());
          ?>
            <article class="yana-sale-product">
              <a class="yana-sale-product-image" href="<?php echo esc_url($product_url); ?>"><?php echo wp_kses_post($product->get_image('woocommerce_thumbnail')); ?><span class="yana-sale-product-badge"><?php echo esc_html($title); ?></span></a>
              <div class="yana-sale-product-info"><a class="yana-sale-product-name" href="<?php echo esc_url($product_url); ?>"><?php echo esc_html($product->get_name()); ?></a><div class="yana-sale-product-price"><?php echo wp_kses_post($product->get_price_html()); ?></div><a class="yana-sale-product-button" href="<?php echo esc_url($product_url); ?>">View Deal <span>→</span></a></div>
            </article>
          <?php endforeach; ?>
        </div>
        <?php if ($total_pages > 1): ?><nav class="yana-sale-pagination" aria-label="Sale products pages">
          <?php for ($p = 1; $p <= $total_pages; $p++): ?><a class="<?php echo $p === $page ? 'is-current' : ''; ?>" href="<?php echo esc_url(add_query_arg(array('yana_sale' => $type, 'yana_sale_page' => $p), home_url('/'))); ?>"><?php echo esc_html($p); ?></a><?php endfor; ?>
        </nav><?php endif; ?>
      <?php endif; ?>
    </main>
    <?php
    get_footer();
    exit;
}
add_action('template_redirect', 'yana_sale_banner_collection_page', 1);
