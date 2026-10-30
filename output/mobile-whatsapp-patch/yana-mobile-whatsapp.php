<?php
/**
 * Plugin Name: Yana Mobile WhatsApp Button
 * Description: Adds a mobile-only WhatsApp chat button beside the mobile menu.
 * Version: 1.0.0
 * Author: Yana Worldwide
 */
if (!defined('ABSPATH')) { exit; }

add_action('wp_head', function () {
    if (is_admin()) { return; }
    ?>
    <style id="yana-mobile-whatsapp-style">
      .yana-mobile-whatsapp-button { display: none !important; }
      @media (max-width: 767px) {
        header.et-mobile .yana-mobile-whatsapp-button {
          display: inline-flex !important;
          align-items: center;
          justify-content: center;
          box-sizing: border-box;
          flex: 0 0 40px;
          width: 40px;
          height: 40px;
          margin: 0 8px;
          padding: 7px;
          border-radius: 50%;
          background: #25d366;
          color: #fff !important;
          text-decoration: none !important;
          box-shadow: 0 2px 7px rgba(0,0,0,.18);
          -webkit-tap-highlight-color: transparent;
        }
        header.et-mobile .yana-mobile-whatsapp-button svg {
          display: block;
          width: 100%;
          height: 100%;
          fill: currentColor;
        }
      }
    </style>
    <?php
}, 99);

add_action('wp_footer', function () {
    if (is_admin()) { return; }
    ?>
    <script id="yana-mobile-whatsapp-script">
    (function () {
      var message = 'Hi, could you please send me the product and price list?';
      function addButtons() {
        var headers = document.querySelectorAll('header.et-mobile');
        headers.forEach(function (header) {
          var toggleWidget = header.querySelector('.elementor-widget-et_mobile_toggle');
          if (!toggleWidget || header.querySelector('.yana-mobile-whatsapp-button')) return;
          var link = document.createElement('a');
          link.className = 'yana-mobile-whatsapp-button';
          link.href = 'https://wa.me/919166666554?text=' + encodeURIComponent(message);
          link.target = '_blank';
          link.rel = 'noopener noreferrer';
          link.title = 'Chat on WhatsApp';
          link.setAttribute('aria-label', 'Chat on WhatsApp to request the product and price list');
          link.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M20.52 3.48A11.8 11.8 0 0 0 12.1 0C5.56 0 .24 5.32.23 11.86c0 2.09.55 4.13 1.59 5.93L.13 24l6.35-1.67a11.9 11.9 0 0 0 5.61 1.43h.01c6.54 0 11.86-5.32 11.87-11.86a11.8 11.8 0 0 0-3.45-8.42ZM12.1 21.74h-.01a9.85 9.85 0 0 1-5.02-1.37l-.36-.21-3.77.99 1.01-3.68-.24-.38a9.82 9.82 0 0 1-1.51-5.23c0-5.46 4.44-9.9 9.9-9.9a9.83 9.83 0 0 1 7 2.9 9.83 9.83 0 0 1 2.9 7c-.01 5.45-4.45 9.88-9.9 9.88Zm5.43-7.4c-.3-.15-1.76-.87-2.03-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.64.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.6.13-.14.3-.35.45-.52.15-.18.2-.3.3-.5.1-.2.05-.37-.03-.52-.07-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51h-.57c-.2 0-.52.08-.79.38-.27.3-1.04 1.02-1.04 2.48s1.06 2.88 1.21 3.08c.15.2 2.1 3.2 5.08 4.49.71.31 1.27.49 1.7.63.71.23 1.36.19 1.87.12.57-.09 1.76-.72 2.01-1.42.25-.69.25-1.29.17-1.41-.07-.12-.27-.2-.57-.35Z"/></svg>';
          toggleWidget.parentNode.insertBefore(link, toggleWidget);
        });
      }
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addButtons);
      } else {
        addButtons();
      }
    })();
    </script>
    <?php
}, 99);
