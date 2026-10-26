<?php
/**
 * Plugin Name: Yana App Download Banner
 * Description: Adds Android and iOS download links as a third card beside the homepage sale banners.
 * Version: 1.0.0
 * Author: Yana Worldwide
 */

if (!defined('ABSPATH')) {
    exit;
}

function yana_app_download_banner_styles() {
    if (!is_front_page() || !wp_style_is('yana-sale-banners', 'enqueued')) {
        return;
    }

    $css = <<<'CSS'
.yana-sale-banners{grid-template-columns:repeat(3,minmax(0,1fr))}
.yana-app-card{isolation:isolate;background:#11170f!important;color:#fff!important;cursor:default}
.yana-app-card:before{background:radial-gradient(ellipse at 93% 12%,#9bd83b55 0,transparent 38%),linear-gradient(120deg,#172016 0%,#0b0e0b 100%)}
.yana-app-copy{position:absolute;z-index:1;inset:8% 37% 7% 5.5%;display:flex;flex-direction:column;align-items:flex-start;min-width:0}
.yana-app-kicker{display:inline-flex;align-items:center;gap:6px;color:#c6f778;font-size:clamp(8px,.75vw,11px);font-weight:900;letter-spacing:.1em;text-transform:uppercase}
.yana-app-kicker:before{content:"";width:7px;height:7px;border-radius:50%;background:#b9ef55;box-shadow:0 0 10px #b9ef55}
.yana-app-title{margin:9px 0 5px;color:#fff;font-size:clamp(18px,2vw,27px);font-weight:900;line-height:1.02;letter-spacing:-.035em}
.yana-app-description{max-width:220px;margin:0;color:#d2d8cd;font-size:clamp(9px,.9vw,12px);font-weight:500;line-height:1.35}
.yana-app-buttons{display:flex;flex-direction:column;gap:6px;width:100%;max-width:190px;margin-top:auto}
.yana-app-store{box-sizing:border-box;display:flex;align-items:center;gap:7px;min-height:34px;padding:5px 8px;border:1px solid #ffffff35;border-radius:5px;background:#f4f7ed;color:#12170e!important;text-decoration:none!important;box-shadow:0 2px 7px #0003;transition:transform .18s ease,background .18s ease}
.yana-app-store:hover{transform:translateY(-1px);background:#dfffaa;color:#10150d!important}
.yana-app-store--apple{border-color:#ffffff45;background:#080a08;color:#fff!important}
.yana-app-store--apple:hover{background:#252a22;color:#fff!important}
.yana-app-store svg{flex:0 0 17px;width:17px;height:17px}
.yana-app-store-copy{display:flex;flex-direction:column;min-width:0;line-height:1.05}
.yana-app-store-copy small{font-size:7px;font-weight:600;letter-spacing:.02em}
.yana-app-store-copy strong{overflow:hidden;font-size:clamp(9px,.9vw,12px);font-weight:800;white-space:nowrap;text-overflow:ellipsis}
.yana-app-phone{position:absolute;z-index:0;top:8%;right:6%;width:30%;max-width:132px;height:84%;box-sizing:border-box;padding:5px;border:2px solid #697263;border-radius:18px;background:#080a08;box-shadow:0 8px 20px #0008,0 0 0 1px #fff2;transform:rotate(3deg)}
.yana-app-phone-screen{position:relative;display:flex;height:100%;overflow:hidden;flex-direction:column;align-items:center;box-sizing:border-box;padding:11px 7px 8px;border-radius:12px;background:linear-gradient(155deg,#d1ff77 0%,#a9e846 48%,#edf7dd 100%);color:#11170d;text-align:center}
.yana-app-phone-notch{position:absolute;top:4px;left:50%;width:27px;height:5px;border-radius:0 0 5px 5px;background:#10140e;transform:translateX(-50%)}
.yana-app-phone-logo{display:grid;place-items:center;width:34px;height:34px;margin-top:8px;border:2px solid #11170d;border-radius:10px;background:#11170d;color:#c9f875;font-size:21px;font-weight:1000;line-height:1}
.yana-app-phone-brand{margin-top:5px;font-size:clamp(6px,.65vw,9px);font-weight:1000;letter-spacing:.06em}
.yana-app-phone-caption{margin-top:3px;font-size:clamp(6px,.6vw,8px);font-weight:700}
.yana-app-phone-pills{display:flex;flex-direction:column;gap:4px;width:100%;margin-top:9px}
.yana-app-phone-pills span{display:block;padding:4px 3px;border:1px solid #52643b38;border-radius:4px;background:#ffffffb8;font-size:clamp(5px,.55vw,7px);font-weight:900;letter-spacing:.04em}
@media(max-width:980px){.yana-sale-banners{grid-template-columns:repeat(2,minmax(0,1fr))}.yana-app-copy{right:37%}.yana-app-title{font-size:clamp(20px,3vw,29px)}.yana-app-description{font-size:clamp(10px,1.4vw,13px)}}
@media(max-width:600px){.yana-sale-banners{grid-template-columns:minmax(0,1fr)}.yana-app-card{aspect-ratio:1.66}.yana-app-copy{inset:8% 39% 7% 5.5%}.yana-app-kicker{font-size:10px}.yana-app-title{font-size:clamp(23px,7vw,31px)}.yana-app-description{font-size:12px}.yana-app-buttons{max-width:205px;gap:7px}.yana-app-store{min-height:38px;padding:6px 9px}.yana-app-store-copy small{font-size:8px}.yana-app-store-copy strong{font-size:12px}.yana-app-phone{width:30%;max-width:142px}.yana-app-phone-brand{font-size:8px}.yana-app-phone-caption{font-size:7px}.yana-app-phone-pills span{font-size:6px}}
@media(prefers-reduced-motion:reduce){.yana-app-store{transition:none}}
CSS;

    wp_add_inline_style('yana-sale-banners', $css);
}
add_action('wp_enqueue_scripts', 'yana_app_download_banner_styles', 30);

function yana_app_download_banner_markup() {
    if (!is_front_page() || !wp_script_is('yana-sale-banners', 'enqueued')) {
        return;
    }
    ?>
    <script id="yana-app-download-banner-script">
    (function () {
      var playUrl = 'https://play.google.com/store/apps/details?id=com.yanaworldwide.shop';
      var appStoreUrl = 'https://apps.apple.com/in/app/yanaworldwide/id6772871793';
      function addAppCard() {
        var row = document.querySelector('.yana-sale-banners');
        if (!row || row.querySelector('.yana-app-card')) return;
        var card = document.createElement('section');
        card.className = 'yana-sale-card yana-app-card';
        card.setAttribute('aria-label', 'Download the Yana Worldwide app');
        card.innerHTML = '<div class="yana-app-copy"><span class="yana-app-kicker">Yana app</span><h2 class="yana-app-title">Your ride.<br>One app.</h2><p class="yana-app-description">Shop bike gear, track orders and catch app-only offers.</p><div class="yana-app-buttons"><a class="yana-app-store" href="' + playUrl + '" target="_blank" rel="noopener noreferrer" aria-label="Get Yana Worldwide on Google Play"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#34a853" d="M3.3 2.7c-.5.3-.8.9-.8 1.7v15.2c0 .8.3 1.4.8 1.7l8.4-9.3z"/><path fill="#4285f4" d="m3.9 21.5 10.4-9.1-2.6-2.8z"/><path fill="#fbbc04" d="m14.3 12.4 5.2 2.9c1.2.7 1.2 1.8 0 2.5l-4.9 2.8-5.8-5.1z"/><path fill="#ea4335" d="m3.3 2.7 8.4 9.3 2.6-2.8-7.8-6.9c-1.2-1-2.5-.6-3.2.4"/></svg><span class="yana-app-store-copy"><small>GET IT ON</small><strong>Google Play</strong></span></a><a class="yana-app-store yana-app-store--apple" href="' + appStoreUrl + '" target="_blank" rel="noopener noreferrer" aria-label="Download Yana Worldwide on the App Store"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M16.7 12.8c0-2.1 1.7-3.1 1.8-3.2-1-1.5-2.6-1.7-3.2-1.8-1.4-.1-2.7.8-3.4.8-.7 0-1.8-.8-2.9-.8-1.5 0-2.9.9-3.7 2.2-1.6 2.8-.4 6.9 1.1 9.1.8 1.1 1.6 2.3 2.7 2.2 1.1 0 1.5-.7 2.9-.7s1.8.7 2.9.7c1.2 0 1.9-1.1 2.6-2.2.8-1.2 1.2-2.5 1.2-2.5s-2.3-.9-2.3-3.8M14.5 6.4c.6-.8 1-1.9.9-3-.9 0-2 .6-2.7 1.4-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.5 2.8-1.3"/></svg><span class="yana-app-store-copy"><small>DOWNLOAD ON THE</small><strong>App Store</strong></span></a></div></div><div class="yana-app-phone" aria-hidden="true"><div class="yana-app-phone-screen"><span class="yana-app-phone-notch"></span><span class="yana-app-phone-logo">Y</span><span class="yana-app-phone-brand">YANAWORLDWIDE</span><span class="yana-app-phone-caption">Ride more. Explore more.</span><div class="yana-app-phone-pills"><span>BIKE ACCESSORIES</span><span>RIDING GEAR</span><span>EXCLUSIVE DEALS</span></div></div></div>';
        row.appendChild(card);
      }
      if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', addAppCard);
      else addAppCard();
    })();
    </script>
    <?php
}
add_action('wp_footer', 'yana_app_download_banner_markup', 99);
