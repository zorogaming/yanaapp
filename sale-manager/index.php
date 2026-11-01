<?php
declare(strict_types=1);
session_name('yana_sale_manager');
session_set_cookie_params(['httponly' => true, 'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off', 'samesite' => 'Strict', 'path' => '/']);
session_start();
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: same-origin');
header('Permissions-Policy: camera=(self)');
$configured = is_file(__DIR__ . '/config.php');
$loggedIn = !empty($_SESSION['sale_manager_authenticated']);
$csrf = $_SESSION['sale_manager_csrf'] ?? '';
?><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#101b2c"><title>Sale Price Manager</title>
  <style>
    :root{font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;color:#172033;background:#f3f6fa;font-synthesis:none}*{box-sizing:border-box}body{margin:0}button,input{font:inherit}button{cursor:pointer}.top{background:#101b2c;color:white;padding:20px max(18px,calc((100vw - 900px)/2));display:flex;align-items:center;justify-content:space-between}.top h1{font-size:20px;margin:0}.top p{color:#b8c4d5;margin:5px 0 0;font-size:13px}.wrap{max-width:900px;margin:22px auto;padding:0 16px 100px}.panel,.product{background:#fff;border:1px solid #e0e6ee;border-radius:16px;padding:18px;margin-bottom:14px;box-shadow:0 5px 20px #1b2c4410}.row{display:flex;gap:10px}.search{display:flex;gap:9px}.search input{flex:1;min-width:0}.field{width:100%;border:1px solid #cbd5e1;border-radius:10px;padding:12px;background:#fff;color:#172033}.btn{border:0;border-radius:10px;padding:12px 16px;font-weight:700;background:#1769e0;color:#fff}.btn.secondary{background:#e9eff7;color:#1b2b40}.btn.danger{background:#b42318}.btn:disabled{opacity:.5;cursor:wait}.scanbar{display:flex;gap:9px;margin-top:10px}.hint,.subtle{color:#64748b;font-size:13px;line-height:1.5}.status{padding:11px 13px;border-radius:10px;background:#edf4ff;margin:12px 0;color:#24436d}.status.error{background:#fff0ee;color:#8b251a}.status.ok{background:#eaf8ef;color:#176039}.product h2{font-size:17px;margin:0 0 5px}.product-head{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}.badge{font-size:11px;background:#eef3f8;border-radius:999px;padding:5px 8px;color:#44546a;white-space:nowrap}.prices{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:14px 0}.price{background:#f6f8fb;padding:9px;border-radius:9px}.price small{display:block;color:#64748b;margin-bottom:4px}.price b{font-size:14px;overflow-wrap:anywhere}.edit{display:grid;grid-template-columns:1fr auto;gap:8px;align-items:center}.edit .field{min-width:0}.ready{font-size:12px;color:#137447;margin-top:8px}.pending{font-size:12px;color:#8a5700;margin-top:8px}.sticky{position:fixed;bottom:0;left:0;right:0;background:#fff;border-top:1px solid #dae1ea;padding:12px max(16px,calc((100vw - 900px)/2));display:flex;gap:10px;align-items:center;justify-content:space-between;box-shadow:0 -6px 20px #1b2c440d}.sticky .btn{flex:1;max-width:380px}.hidden{display:none!important}.empty{text-align:center;color:#64748b;padding:28px}.setup{max-width:560px;margin:50px auto}.setup code{overflow-wrap:anywhere}@media(max-width:560px){.top{padding:16px}.wrap{margin-top:14px}.panel,.product{padding:14px}.search{flex-wrap:wrap}.search input{flex-basis:100%}.search .btn{flex:1}.prices{grid-template-columns:1fr 1fr}.prices .price:last-child{grid-column:1/-1}.edit{grid-template-columns:1fr}.sticky{padding-bottom:max(12px,env(safe-area-inset-bottom))}}
  </style>
  <style>
    .top-actions{display:flex;align-items:center;gap:8px}.history-state{font-size:12px;font-weight:700;border-radius:999px;padding:5px 9px}.history-state.success{background:#eaf8ef;color:#176039}.history-state.failed{background:#fff0ee;color:#8b251a}.history-prices{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:12px 0}.history-error{color:#8b251a;font-size:13px;margin-top:8px;overflow-wrap:anywhere}@media(max-width:560px){.top-actions{gap:6px}.top-actions .btn{padding:10px}.history-prices{grid-template-columns:1fr 1fr}}
  </style>
  <style>.search textarea{flex:1;min-width:0;min-height:52px;resize:vertical}.cost-box{display:grid;gap:6px;margin:14px 0}.cost-label{font-size:13px;font-weight:700;color:#344256}.cost-status{min-height:18px}.profit-line{padding:10px 12px;border-radius:9px;margin:10px 0;font-size:14px;font-weight:700}.profit{background:#eaf8ef;color:#176039}.loss{background:#fff0ee;color:#8b251a}.history-state.detected{background:#eaf2ff;color:#24436d}.history-prices{grid-template-columns:repeat(4,minmax(0,1fr))}@media(max-width:560px){.search textarea{flex-basis:100%}.history-prices{grid-template-columns:1fr 1fr}}</style>
  <style>.top-actions{flex-wrap:wrap;justify-content:flex-end}.row{flex-wrap:wrap}@media(max-width:560px){.top{align-items:flex-start;gap:10px}.top-actions{max-width:52%}.top-actions .btn{font-size:12px;padding:8px 9px}.row .btn{flex:1}}</style>
</head>
<body>
<header class="top"><div><h1>Sale Price Manager</h1><p>Scan products, save drafts, publish only when you’re ready.</p></div><div class="top-actions"><button id="draftsBtn" class="btn secondary hidden" type="button">Saved Drafts</button><button id="historyBtn" class="btn secondary hidden" type="button">History</button><button id="logout" class="btn secondary hidden" type="button">Log out</button></div></header>
<main class="wrap">
  <section id="setup" class="panel setup hidden"><h2>Finish server setup</h2><p>This page is ready, but <code>config.php</code> is missing. Copy <code>config.example.php</code> to <code>config.php</code>, add your WooCommerce API credentials and a password hash, then set a private writable JSON storage folder. See <code>README.md</code>.</p></section>
  <section id="login" class="panel setup hidden"><h2>Sign in</h2><p class="subtle">Use the password configured on the server.</p><form id="loginForm"><input class="field" name="password" type="password" autocomplete="current-password" required placeholder="Admin password"><button class="btn" style="width:100%;margin-top:10px">Sign in</button></form><div id="loginMessage" class="status hidden"></div></section>
  <div id="app" class="hidden">
    <section class="panel"><label for="productSearch">Search saved products / history</label><input id="productSearch" class="field" type="search" placeholder="Product name, SKU or ID" autocomplete="off"><p id="searchResults" class="subtle" role="status"></p></section>
    <div id="mainView">
    <section class="panel"><div class="search"><textarea id="barcode" class="field" rows="2" autocomplete="off" placeholder="Enter one or more barcodes / SKUs, separated by commas"></textarea><button id="find" class="btn" type="button">Find product(s)</button></div><div class="scanbar"><button id="scan" class="btn secondary" type="button">Scan with camera</button><button id="stopScan" class="btn secondary hidden" type="button">Stop camera</button></div><video id="video" class="hidden" playsinline style="width:100%;max-height:320px;margin-top:12px;border-radius:12px;background:#111"></video><p class="hint">The barcode must match the WooCommerce product SKU. Enter multiple SKUs separated by commas or new lines. Camera scanning needs HTTPS and a supported mobile browser.</p><div id="message" class="status hidden"></div></section>
    <section><div class="product-head" style="padding:2px 3px 10px"><strong>Scanned products &amp; saved drafts</strong><span id="count" class="badge">0 items</span></div><div id="items"></div></section>
    </div>
    <section id="draftsView" class="hidden"><div class="panel"><div class="product-head"><div><h2>Saved Drafts</h2><p class="subtle">Review saved prices and upload every draft together.</p></div><button id="backFromDrafts" class="btn secondary" type="button">Back</button></div></div><div id="draftMessage" class="status hidden"></div><div id="draftItems"></div></section>
    <section id="historyView" class="hidden"><div class="panel"><div class="product-head"><div><h2>Upload history</h2><p class="subtle">Sale price changes sent to WooCommerce.</p></div><div class="row"><button id="clearHistory" class="btn danger" type="button">Clear History</button><button id="backToProducts" class="btn secondary" type="button">Back</button></div></div></div><div id="historyMessage" class="status hidden"></div><div id="historyItems"></div></section>
  </div>
</main>
<section id="uploadProgress" class="panel hidden" style="position:fixed;top:0;left:0;right:0;z-index:10000;max-width:900px;margin:0 auto;padding:12px 16px;max-height:42vh;overflow:auto;box-shadow:0 6px 24px #17203333" aria-labelledby="uploadTitle">
<h2 id="uploadTitle" style="font-size:17px;margin:0 0 6px">Website upload progress</h2>
<p id="uploadSummary" role="status" aria-live="polite"></p>
<progress id="uploadMeter" value="0" max="1" aria-label="Products processed" style="width:100%;height:22px;accent-color:#1769e0"></progress>
<p class="subtle">Keep this page open until uploading finishes.</p>
<input id="uploadSearch" class="field" type="search" placeholder="Search upload products by name, SKU or ID" aria-label="Search upload products"><div id="uploadRetryStatus" class="subtle" role="status" aria-live="polite"></div>
<div id="uploadRows" style="max-height:180px;overflow:auto"></div>
</section>
<div id="publishBar" class="sticky hidden"><span id="pendingCount">No prices ready</span><button id="publish" class="btn" type="button">Upload Website</button></div>
<script>
const configured = <?= $configured ? 'true' : 'false' ?>;
const initiallyLoggedIn = <?= $loggedIn ? 'true' : 'false' ?>;
let csrf = <?= json_encode($csrf, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT) ?>;
let items = {};
let activeView='main';
let costTimers = {}, costSaves = {}, costValues = {};
const $ = id => document.getElementById(id);
function message(text, type=''){const el=$(activeView==='drafts'?'draftMessage':activeView==='history'?'historyMessage':'message');el.textContent=text;el.className='status'+(type?' '+type:'');el.classList.remove('hidden')}
async function api(action, data={}){
  const response=await fetch('api.php?action='+encodeURIComponent(action),{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf},body:JSON.stringify(data),credentials:'same-origin'});
  let body;try{body=await response.json()}catch{const error=new Error('The server returned an invalid response.');error.retryable=![401,403,404,422].includes(response.status);throw error;}
  if(!response.ok||!body.ok){const error=new Error(body.error||'Request failed.');error.retryable=[408,425,429,500,502,503,504].includes(response.status);throw error;}return body;
}
function esc(value){return String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function cash(value){return value===null||value===''?'—':'₹'+value}
function renderContent(){const entries=Object.values(items).sort((a,b)=>(b.updated_at||'').localeCompare(a.updated_at||''));$('count').textContent=entries.length+' items';$('items').innerHTML=entries.length?entries.map(item=>{
  const key=String(item.id), ready=item.pending_price!==null&&item.pending_price!==undefined;
  return `<article class="product"><div class="product-head"><div><h2>${esc(item.name||'Product')}</h2><div class="subtle">SKU: ${esc(item.sku||'—')} · ID: ${esc(item.id)}${item.type==='variation'?' · Variation':''}</div></div><span class="badge">${ready?'Draft ready':'Scanned'}</span></div><div class="prices"><div class="price"><small>Locked regular</small><b>${cash(item.locked_regular)}</b></div><div class="price"><small>Locked sale</small><b>${cash(item.locked_sale)}</b></div><div class="price"><small>Current website sale</small><b>${cash(item.current_sale)}</b></div></div><div class="edit"><input class="field pending-input" data-id="${esc(key)}" inputmode="decimal" type="text" placeholder="New sale price (leave blank to clear)" value="${ready?esc(item.pending_price):''}"><button class="btn secondary save" data-id="${esc(key)}" type="button">Save draft</button></div><div class="${ready?'ready':'pending'}">${ready?'Saved as a draft. Website is unchanged.':'No new price saved yet; this item will not be uploaded.'}</div><div class="subtle" style="margin-top:8px">First captured: ${esc(item.locked_at||'—')}</div></article>`
  }).join(''):'<div class="panel empty">No products scanned yet. Enter a SKU or scan a barcode.</div>';
  [...$('items').querySelectorAll('.product')].forEach((card,index)=>{const item=entries[index],id=String(item.id),box=document.createElement('div'),label=document.createElement('label'),input=document.createElement('input'),status=document.createElement('small');box.className='cost-box';label.className='cost-label';label.textContent='Mujhe kitne ka pada?';input.className='field cost-input';input.type='text';input.inputMode='decimal';input.placeholder='Enter your cost price';input.dataset.id=id;input.value=String(item.cost_price??'');status.className='subtle cost-status';status.dataset.id=id;status.textContent='Auto-saves as you type';box.append(label,input,status);const prices=card.querySelector('.prices');if(prices){card.insertBefore(box,prices);const profit=document.createElement('div');profit.className='profit-line';updateProfitLine(profit,item);card.insertBefore(profit,prices.nextSibling)}costValues[id]=input.value;});
  [...$('items').querySelectorAll('.product')].forEach(card=>{const edit=card.querySelector('.edit'),id=card.querySelector('.pending-input')?.dataset.id;if(!edit||!id)return;const button=document.createElement('button');button.type='button';button.className='btn secondary suggest';button.dataset.id=id;button.title='Requires saved cost and locked sale price. Saves a 25% discount as a draft.';button.textContent='AI Suggest (25% off)';edit.appendChild(button)});
  const readyCount=entries.filter(x=>x.pending_price!==null&&x.pending_price!==undefined).length;$('publishBar').classList.add('hidden');$('pendingCount').textContent=readyCount?readyCount+' price'+(readyCount===1?'':'s')+' ready':'No prices ready';$('publish').disabled=readyCount===0;
}
function renderDraftsContent(){const entries=Object.values(items).filter(x=>x.pending_price!==null&&x.pending_price!==undefined).sort((a,b)=>(b.updated_at||'').localeCompare(a.updated_at||''));$('draftItems').innerHTML=entries.length?entries.map(item=>`<article class="product"><div class="product-head"><div><h2>${esc(item.name||'Product')}</h2><div class="subtle">SKU: ${esc(item.sku||'—')} · ID: ${esc(item.id)}${item.type==='variation'?' · Variation':''}</div></div><span class="badge">Saved draft</span></div><div class="prices"><div class="price"><small>Locked regular</small><b>${cash(item.locked_regular)}</b></div><div class="price"><small>Locked sale</small><b>${cash(item.locked_sale)}</b></div><div class="price"><small>Current website sale</small><b>${cash(item.current_sale)}</b></div></div><div class="edit"><input class="field draft-price" data-id="${esc(item.id)}" inputmode="decimal" value="${esc(item.pending_price)}"><button class="btn secondary draft-save" data-id="${esc(item.id)}" type="button">Save draft</button></div></article>`).join(''):'<div class="panel empty">No saved price drafts. Scan a product on the main page and save a sale price first.</div>';$('pendingCount').textContent=entries.length+' saved price'+(entries.length===1?'':'s')+' ready';$('publish').disabled=!entries.length;$('publishBar').classList.toggle('hidden',activeView!=='drafts'||!entries.length)}
function updateProfitLine(node,item){const cost=String(item.cost_price??'').trim(),sale=String(item.locked_sale??'').trim(),regular=String(item.locked_regular??'').trim(),basis=sale!==''?sale:regular,label=sale!==''?'locked sale':'locked regular';if(cost===''){node.className='profit-line subtle';node.textContent='Enter your cost to see estimated profit.';return}if(basis===''||!Number.isFinite(Number(cost))||!Number.isFinite(Number(basis))){node.className='profit-line subtle';node.textContent='A locked selling price is not available for this calculation.';return}const costValue=Number(cost),sellingValue=Number(basis),amount=sellingValue-costValue,margin=sellingValue!==0?(amount/sellingValue*100).toFixed(2)+'%':'N/A',markup=costValue!==0?(amount/costValue*100).toFixed(2)+'%':'N/A';node.className='profit-line '+(amount>=0?'profit':'loss');node.textContent=(amount>=0?'Estimated profit: ':'Estimated loss: ')+cash(Math.abs(amount).toFixed(2))+' · Margin: '+margin+' · Markup: '+markup+' (based on '+label+' price)'}
async function saveCostValue(id,value){const promise=api('save-cost',{id,cost_price:value});costSaves[id]=promise;try{const out=await promise,latest=costValues[id];items[id]=out.item;if(latest!==value)items[id].cost_price=latest;else costValues[id]=String(out.item.cost_price??'');const status=document.querySelector('.cost-status[data-id="'+CSS.escape(id)+'"]');if(status)status.textContent=latest===value?'Cost saved':'Saving…';return true}catch(e){const status=document.querySelector('.cost-status[data-id="'+CSS.escape(id)+'"]');if(status)status.textContent='Save failed — '+e.message;throw e}finally{if(costSaves[id]===promise)delete costSaves[id]}}
function queueCost(input){const id=input.dataset.id,value=input.value.trim();costValues[id]=value;if(items[id])items[id].cost_price=value;const status=document.querySelector('.cost-status[data-id="'+CSS.escape(id)+'"]');if(status)status.textContent='Saving…';const profit=input.closest('.product')?.querySelector('.profit-line');if(profit&&items[id])updateProfitLine(profit,items[id]);if(costTimers[id])clearTimeout(costTimers[id]);costTimers[id]=setTimeout(async()=>{delete costTimers[id];try{if(costSaves[id])await costSaves[id];await saveCostValue(id,costValues[id])}catch{}},650)}
async function flushCostInputs(){for(const input of document.querySelectorAll('.cost-input')){const id=input.dataset.id,value=input.value.trim();if(costTimers[id]){clearTimeout(costTimers[id]);delete costTimers[id]}if(costSaves[id]){try{await costSaves[id]}catch{}}if(costValues[id]!==value||items[id]?.cost_price!==value)costValues[id]=value;try{await saveCostValue(id,value)}catch(e){throw new Error('Could not save cost for '+(items[id]?.name||id)+': '+e.message)}}}
function renderHistoryContent(entries){$('historyItems').innerHTML=entries.length?entries.map(row=>{const good=row.status==='success',newPrice=row.new_sale_price===''?'Sale price cleared':cash(row.new_sale_price);let when=row.uploaded_at||'';try{when=new Date(when).toLocaleString()}catch{}return `<article class="product"><div class="product-head"><div><h2>${esc(row.name||'Product')}</h2><div class="subtle">SKU: ${esc(row.sku||'—')} · ID: ${esc(row.product_id)}${row.type==='variation'?' · Variation':''}</div></div><span class="history-state ${good?'success':'failed'}">${good?'Uploaded':'Failed'}</span></div><div class="history-prices"><div class="price"><small>Locked regular</small><b>${cash(row.locked_regular)}</b></div><div class="price"><small>Locked sale</small><b>${cash(row.locked_sale)}</b></div><div class="price"><small>New sale price</small><b>${newPrice}</b></div></div><div class="subtle">Upload time: ${esc(when)}</div>${row.error?`<div class="history-error">${esc(row.error)}</div>`:''}</article>`}).join(''):'<div class="panel empty">No upload history yet. Successfully or unsuccessfully submitted price changes will appear here.</div>'}
function addHistoryCosts(entries){[...$('historyItems').querySelectorAll('.product')].forEach((card,index)=>{const row=entries[index],priceGrid=card.querySelector('.history-prices');if(!row||!priceGrid)return;const price=document.createElement('div'),cost=String(row.cost_price??''),sale=String(row.locked_sale??''),regular=String(row.locked_regular??'');price.className='price';price.innerHTML='<small>Your cost</small><b>'+esc(cost===''?'—':cash(cost))+'</b>';priceGrid.insertBefore(price,priceGrid.lastElementChild);const sellingValue=sale!==''?Number(sale):Number(regular),costValue=Number(cost);if(cost!==''&&Number.isFinite(costValue)&&Number.isFinite(sellingValue)){const amount=sellingValue-costValue,margin=sellingValue!==0?(amount/sellingValue*100).toFixed(2)+'%':'N/A',markup=costValue!==0?(amount/costValue*100).toFixed(2)+'%':'N/A',profit=document.createElement('div');profit.className='profit-line '+(amount>=0?'profit':'loss');profit.textContent=(amount>=0?'Estimated profit: ':'Estimated loss: ')+cash(Math.abs(amount).toFixed(2))+' · Margin: '+margin+' · Markup: '+markup+' (locked '+(sale!==''?'sale':'regular')+' price)';card.insertBefore(profit,priceGrid.nextSibling)}})}
function decorateHistory(entries){[...$('historyItems').querySelectorAll('.product')].forEach((card,index)=>{const row=entries[index],badge=card.querySelector('.history-state');if(!row||!badge)return;if(row.status==='detected'){badge.className='history-state detected';badge.textContent='Changed earlier';if(row.note){const note=document.createElement('div');note.className='subtle';note.textContent=row.note;card.appendChild(note)}}if(row.status==='success'||row.status==='detected'){const button=document.createElement('button');button.type='button';button.className='btn secondary reopen';button.dataset.id=String(row.product_id);button.textContent='Edit again';button.style.marginTop='12px';card.appendChild(button)}})}
async function openHistory(){activeView='history';$('mainView').classList.add('hidden');$('draftsView').classList.add('hidden');$('historyView').classList.remove('hidden');$('publishBar').classList.add('hidden');$('historyItems').innerHTML='<div class="panel empty">Loading history…</div>';try{const result=await api('history');renderHistory(result.items);addHistoryCosts(result.items);decorateHistory(result.items)}catch(e){$('historyItems').innerHTML='<div class="status error">'+esc(e.message)+'</div>'}}
function closeHistory(){activeView='main';$('historyView').classList.add('hidden');$('draftsView').classList.add('hidden');$('mainView').classList.remove('hidden');render()}
async function openDrafts(){activeView='drafts';$('mainView').classList.add('hidden');$('historyView').classList.add('hidden');$('draftsView').classList.remove('hidden');$('draftMessage').classList.add('hidden');$('draftItems').innerHTML='<div class="panel empty">Loading saved drafts…</div>';try{const result=await api('list');items={};for(const row of result.items)items[String(row.id)]=row;render();renderDrafts()}catch(e){$('draftItems').innerHTML='<div class="status error">'+esc(e.message)+'</div>'}}
function closeDrafts(){activeView='main';$('draftsView').classList.add('hidden');$('historyView').classList.add('hidden');$('mainView').classList.remove('hidden');$('publishBar').classList.add('hidden');render()}
async function clearHistory(){if(!confirm('Clear upload history? A private backup will be saved on the server.'))return;const button=$('clearHistory');button.disabled=true;try{const out=await api('clear-history');renderHistory([]);message(out.message+' ('+out.cleared_count+' records cleared)','ok')}catch(e){message(e.message,'error')}finally{button.disabled=false}}
async function reopenFromHistory(id){try{const out=await api('reopen',{id});items[String(out.item.id)]=out.item;$('historyView').classList.add('hidden');$('mainView').classList.remove('hidden');render();message('Product added back to drafts. Enter and save a new sale price when ready.','ok')}catch(e){$('historyItems').insertAdjacentHTML('afterbegin','<div class="status error">'+esc(e.message)+'</div>')}}
async function refresh(){const result=await api('list');items={};for(const row of result.items)items[String(row.id)]=row;render()}
async function doLogin(event){event.preventDefault();const password=new FormData(event.target).get('password');try{const out=await api('login',{password});csrf=out.csrf;$('login').classList.add('hidden');$('app').classList.remove('hidden');$('logout').classList.remove('hidden');$('draftsBtn').classList.remove('hidden');$('historyBtn').classList.remove('hidden');await refresh()}catch(e){$('loginMessage').textContent=e.message;$('loginMessage').classList.remove('hidden')}}
async function findProduct(){const skus=[...new Set($('barcode').value.split(/[\n,]+/).map(x=>x.trim()).filter(Boolean))];if(!skus.length){message('Enter or scan at least one product SKU.','error');return}if(skus.length>100){message('Please enter no more than 100 SKUs at a time.','error');return}$('find').disabled=true;const failed=[];let loaded=0,hidden=0;try{for(let i=0;i<skus.length;i++){message('Looking up '+(i+1)+' of '+skus.length+'…');try{const out=await api('lookup',{sku:skus[i]});for(const row of out.items)items[String(row.id)]=row;loaded++;hidden+=Number(out.hidden_count||0)}catch(e){failed.push(skus[i]+' ('+e.message+')')}render()}$('barcode').value=failed.map(x=>x.split(' (')[0]).join(', ');if(failed.length)message('Loaded '+loaded+' barcode(s). Could not load: '+failed.join(', '),'error');else if(hidden)message('Loaded '+loaded+' barcode(s). '+hidden+' already-changed item(s) stayed off the main list. Use History → Edit again if needed.','ok');else message('Loaded '+loaded+' barcode(s). Prices are still drafts; website unchanged.','ok')}finally{$('find').disabled=false}}
async function saveDraft(button){const id=button.dataset.id,input=document.querySelector('.pending-input[data-id="'+CSS.escape(id)+'"]');button.disabled=true;try{const out=await api('save-draft',{id,pending_price:input.value.trim()});items[String(out.item.id)]=out.item;render()}catch(e){message(e.message,'error')}finally{button.disabled=false}}
async function saveDraftFromPage(button){const id=button.dataset.id,input=document.querySelector('.draft-price[data-id="'+CSS.escape(id)+'"]');button.disabled=true;try{const out=await api('save-draft',{id,pending_price:input.value.trim()});items[String(out.item.id)]=out.item;renderDrafts()}catch(e){message(e.message,'error')}finally{button.disabled=false}}
async function suggestPrice(button){const id=button.dataset.id,input=document.querySelector('.cost-input[data-id="'+CSS.escape(id)+'"]'),cost=input?.value.trim()??'';if(cost===''){message('Enter your cost first. It is required for AI Suggest.','error');input?.focus();return}button.disabled=true;try{if(costTimers[id]){clearTimeout(costTimers[id]);delete costTimers[id]}if(costSaves[id]){try{await costSaves[id]}catch{}}await saveCostValue(id,cost);const out=await api('suggest-price',{id});items[String(out.item.id)]=out.item;render();message('Suggested price '+cash(out.item.pending_price)+' (25% below locked '+out.basis_type+') saved as a draft. Website unchanged.','ok')}catch(e){message(e.message,'error')}finally{button.disabled=false}}
function applyProductSearch(){
  const query=$('productSearch').value.trim().toLowerCase();
  const target=$(activeView==='drafts'?'draftItems':activeView==='history'?'historyItems':'items');
  const cards=[...target.querySelectorAll('.product')];let visible=0;
  for(const card of cards){const match=!query||card.textContent.toLowerCase().includes(query);card.hidden=!match;if(match)visible++;}
  $('searchResults').textContent=query?visible+' matching product(s) / '+cards.length:'';
}
function render(){renderContent();applyProductSearch();}
function renderDrafts(){renderDraftsContent();applyProductSearch();}
function renderHistory(entries){renderHistoryContent(entries);applyProductSearch();}
function applyUploadSearch(){
  const query=$('uploadSearch').value.trim().toLowerCase();
  for(const row of $('uploadRows').children)row.hidden=!!query&&!row.textContent.toLowerCase().includes(query);
}
$('productSearch').addEventListener('input',applyProductSearch);
$('uploadSearch').addEventListener('input',applyUploadSearch);
function temporaryUploadError(error){
  if(error.retryable===false)return false;
  return error.retryable===true||error instanceof TypeError||/invalid response|network|failed to fetch|connection failed|timed? ?out|HTTP (408|425|429|500|502|503|504)/i.test(error.message);
}
async function publishWithRetry(id){
  const delays=[5,10,20,30,60];
  for(let attempt=0;;attempt++){
    try{
      $('uploadRetryStatus').textContent='';
      const out=await api('publish',{ids:[id]});
      if(out.failed&&temporaryUploadError(new Error(out.message))){const error=new Error(out.message);error.retryable=true;throw error;}
      return out;
    }catch(error){
      if(!temporaryUploadError(error)||attempt>=delays.length)throw error;
      for(let seconds=delays[attempt];seconds>0;seconds--){
        uploadRowState(id,'Paused - retry '+(attempt+1)+' / '+delays.length,error.message,'#8a5700');
        $('uploadRetryStatus').textContent='Server busy. Retrying this product in '+seconds+'s. Completed products will be skipped.';
        await new Promise(resolve=>setTimeout(resolve,1000));
      }
      uploadRowState(id,'Retrying...','Checking the same saved draft.','#1769e0');
    }
  }
}

let publishing=false;
window.addEventListener('beforeunload',event=>{if(publishing){event.preventDefault();event.returnValue=''}});
function uploadRowState(id,label,detail='',color='#64748b'){
  const row=$('upload-row-'+id);if(!row)return;
  const state=row.querySelector('.upload-state');state.textContent=label;state.style.color=color;
  const list=$('uploadRows');list.scrollTop=row.offsetTop-list.offsetTop;
  row.querySelector('.upload-detail').textContent=detail;
}
async function publish(){
  if(publishing)return;
  publishing=true;$('publish').disabled=true;
  let uploaded=0,processed=0,failed=0,currentId=null,started=false;
  const summary=()=>{
    $('uploadMeter').value=processed;
    $('uploadSummary').textContent=processed+' / '+$('uploadMeter').max+' processed ? '+uploaded+' uploaded ? '+failed+' failed';
  };
  try{
    await flushCostInputs();
    const latest=await api('list');items={};for(const row of latest.items)items[String(row.id)]=row;
    const queue=Object.values(items).filter(x=>x.pending_price!==null&&x.pending_price!==undefined);
    if(!queue.length)return;
    if(!confirm('Upload all '+queue.length+' saved sale price draft(s) to the live WooCommerce website now? Prices change immediately.'))return;
    started=true;$('uploadProgress').classList.remove('hidden');
    $('uploadMeter').max=queue.length;$('uploadMeter').value=0;
    $('uploadRows').innerHTML=queue.map(row=>`<div id="upload-row-${esc(row.id)}" style="padding:12px 0;border-bottom:1px solid #e0e6ee"><strong>${esc(row.name||'Product')}</strong><div class="subtle">SKU: ${esc(row.sku||'?')} ? ID: ${esc(row.id)} ? Sale price: ${esc(row.pending_price===''?'Clear sale':cash(row.pending_price))}</div><b class="upload-state" style="color:#64748b">Waiting</b><div class="upload-detail subtle"></div></div>`).join('');
    summary();applyUploadSearch();
    for(const row of queue){
      currentId=String(row.id);
      uploadRowState(currentId,'Processing?','Saving price and checking Big Days Sale.','#1769e0');
      const out=await publishWithRetry(currentId);
      processed++;
      if(out.updated_ids.map(String).includes(currentId)||((out.already_completed_ids||[]).map(String).includes(currentId))){
        uploaded++;uploadRowState(currentId,'? Ho gaya ? Uploaded','Sale price saved; Big Days Sale checkbox verified. Already completed products are skipped.','#137447');
      }else if(out.failed){
        failed++;uploadRowState(currentId,'? Failed ? retry needed',out.message,'#b42318');
      }else{
        uploadRowState(currentId,'Skipped ? no pending draft','This request did not upload this product. Check History.','#8a5700');
      }
      items={};for(const remaining of out.remaining)items[String(remaining.id)]=remaining;
      summary();currentId=null;
      // One request at a time, with a short pause before the next product.
      await new Promise(resolve=>setTimeout(resolve,800));
    }
    $('uploadSummary').textContent+=' ? Finished';
    message(uploaded+' product(s) uploaded. '+failed+' failed; failed drafts remain for retry.',failed?'error':'ok');
  }catch(e){
    if(started){
      if(currentId)uploadRowState(currentId,'? Result not confirmed',e.message+' Refresh and retry this saved draft.','#b42318');
      for(const state of $('uploadRows').querySelectorAll('.upload-state'))if(state.textContent==='Waiting')state.textContent='Not started ? upload stopped';
      summary();$('uploadSummary').textContent+=' ? Stopped';
    }
    message('Upload stopped after '+uploaded+' confirmed product(s). '+e.message+' Refresh and upload remaining drafts to continue.','error');
  }finally{$('uploadRetryStatus').textContent='';publishing=false;if(activeView==='drafts')renderDrafts();else render()}
}

let stream=null, scanTimer=null;
async function startScan(){if(!('BarcodeDetector'in window)){message('This browser does not support camera barcode scanning. Enter the SKU manually or use a recent Chrome on Android.','error');return}try{const detector=new BarcodeDetector({formats:['ean_13','ean_8','upc_a','upc_e','code_128','code_39','itf']});stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'}},audio:false});$('video').srcObject=stream;$('video').classList.remove('hidden');$('scan').classList.add('hidden');$('stopScan').classList.remove('hidden');await $('video').play();scanTimer=setInterval(async()=>{if(!$('video').videoWidth)return;try{const found=await detector.detect($('video'));if(found.length){$('barcode').value=found[0].rawValue;stopScan();findProduct()}}catch{}},300)}catch(e){message('Could not open camera. Allow camera access and use the page over HTTPS.','error');stopScan()}}
function stopScan(){if(scanTimer)clearInterval(scanTimer);scanTimer=null;if(stream)stream.getTracks().forEach(t=>t.stop());stream=null;$('video').srcObject=null;$('video').classList.add('hidden');$('scan').classList.remove('hidden');$('stopScan').classList.add('hidden')}
$('loginForm').addEventListener('submit',doLogin);$('find').addEventListener('click',findProduct);$('barcode').addEventListener('keydown',e=>{if(e.key==='Enter')findProduct()});$('items').addEventListener('click',e=>{const b=e.target.closest('.save');if(b)saveDraft(b)});$('draftItems').addEventListener('click',e=>{const b=e.target.closest('.draft-save');if(b)saveDraftFromPage(b)});$('publish').addEventListener('click',publish);$('scan').addEventListener('click',startScan);$('stopScan').addEventListener('click',stopScan);$('draftsBtn').addEventListener('click',openDrafts);$('historyBtn').addEventListener('click',openHistory);$('backToProducts').addEventListener('click',closeHistory);$('backFromDrafts').addEventListener('click',closeDrafts);$('clearHistory').addEventListener('click',clearHistory);$('logout').addEventListener('click',async()=>{await api('logout');location.reload()});
$('items').addEventListener('click',e=>{const button=e.target.closest('.suggest');if(button)suggestPrice(button)});
$('items').addEventListener('input',e=>{const input=e.target.closest('.cost-input');if(input)queueCost(input)});
$('historyItems').addEventListener('click',e=>{const button=e.target.closest('.reopen');if(button)reopenFromHistory(button.dataset.id)});
if(!configured){$('setup').classList.remove('hidden')}else if(initiallyLoggedIn){$('app').classList.remove('hidden');$('logout').classList.remove('hidden');$('draftsBtn').classList.remove('hidden');$('historyBtn').classList.remove('hidden');refresh().catch(e=>message(e.message,'error'))}else{$('login').classList.remove('hidden')}
</script>
</body></html>
