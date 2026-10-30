(function () {
  function insertBanners() {
    if (!document.body.classList.contains('home')) return;
    var section = document.querySelector('.section-carousel.elementor-element-e2c0a9c');
    if (!section) {
      var heading = Array.prototype.find.call(document.querySelectorAll('h1'), function (node) {
        return node.textContent.trim().toLowerCase() === 'select your motorcycle';
      });
      if (heading) section = heading.closest('.e-con.e-parent') || heading.closest('.elementor-element');
    }
    if (!section || document.querySelector('.yana-sale-banners')) return;
    var wrap = document.createElement('div');
    wrap.className = 'yana-sale-banners';
    wrap.setAttribute('aria-label', 'Sale offers');
    wrap.innerHTML = '<a class="yana-sale-card yana-sale-daily" href="#"><span class="yana-sale-art"></span><span class="yana-sale-corner-icon yana-bolt">ϟ</span><span class="yana-sale-title">Daily Sale</span><span class="yana-sale-main"><b class="yana-sale-percent">50%</b><b class="yana-sale-off">OFF</b></span><span class="yana-sale-clock-label">Ends in</span><span class="yana-sale-clock"><i>--</i><em>:</em><i>--</i><em>:</em><i>--</i></span><span class="yana-sale-cta">Explore Deals <b aria-hidden="true">→</b></span></a>' +
      '<a class="yana-sale-card yana-sale-big" href="#"><span class="yana-sale-art"></span><span class="yana-sale-corner-icon yana-crown">♛</span><span class="yana-sale-title">Big Days Sale</span><span class="yana-sale-big-up">Up to</span><span class="yana-sale-main"><b class="yana-sale-percent">70%</b><b class="yana-sale-off">OFF</b></span><span class="yana-sale-big-sub">On Selected Brands</span><span class="yana-sale-cta">Explore Deals <b aria-hidden="true">→</b></span></a>';
    var daily = wrap.querySelector('.yana-sale-daily');
    var big = wrap.querySelector('.yana-sale-big');
    daily.href = YanaSaleBanners.dailyUrl;
    big.href = YanaSaleBanners.bigDaysUrl;
    daily.querySelector('.yana-sale-art').style.backgroundImage = 'url("' + YanaSaleBanners.helmet + '")';
    big.querySelector('.yana-sale-art').style.backgroundImage = 'url("' + YanaSaleBanners.jacket + '")';
    if (!YanaSaleBanners.dailyEnabled) {
      daily.classList.add('is-closed');
      daily.querySelector('.yana-sale-main').innerHTML = '<b class="yana-sale-closed">CLOSED</b>';
      daily.querySelector('.yana-sale-clock-label').textContent = 'Sale currently unavailable';
      daily.querySelector('.yana-sale-clock').remove();
    } else startDailyClock(daily);
    if (!YanaSaleBanners.bigDaysEnabled) {
      big.classList.add('is-upcoming');
      big.querySelector('.yana-sale-title').textContent = YanaSaleBanners.bigDaysLabel || 'Big Days Sale';
      big.querySelector('.yana-sale-big-up').remove();
      big.querySelector('.yana-sale-main').innerHTML = '<b class="yana-sale-upcoming-text"></b>';
      big.querySelector('.yana-sale-upcoming-text').textContent = YanaSaleBanners.upcomingMessage || YanaSaleBanners.upcomingLabel || 'Coming Soon';
      big.querySelector('.yana-sale-big-sub').textContent = 'Coming Soon';
    }
    section.parentNode.insertBefore(wrap, section);
  }
  function startDailyClock(card) {
    var label = card.querySelector('.yana-sale-clock-label');
    var clock = card.querySelector('.yana-sale-clock');
    function tick() {
      var now = new Date();
      var start = new Date(now); start.setHours(10, 0, 0, 0);
      var end = new Date(now); end.setHours(19, 0, 0, 0);
      var target, live = now >= start && now < end;
      if (live) { target = end; label.textContent = 'Ends in'; }
      else if (now < start) { target = start; label.textContent = 'Starts in'; }
      else { target = new Date(start); target.setDate(start.getDate() + 1); label.textContent = 'Starts in'; }
      var seconds = Math.max(0, Math.floor((target - now) / 1000));
      var values = [String(Math.floor(seconds / 3600)).padStart(2, '0'), String(Math.floor(seconds / 60) % 60).padStart(2, '0'), String(seconds % 60).padStart(2, '0')];
      clock.querySelectorAll('i').forEach(function (node, index) { node.textContent = values[index]; });
      card.classList.toggle('is-closed', !live);
    }
    tick(); window.setInterval(tick, 1000);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', insertBanners);
  else insertBanners();
})();
