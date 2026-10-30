<?php
declare(strict_types=1);
session_name('yana_sale_manager');
session_set_cookie_params(['httponly' => true, 'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off', 'samesite' => 'Strict', 'path' => '/']);
session_start();
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
header('X-Content-Type-Options: nosniff');

function respond(array $data, int $status=200): never { http_response_code($status); echo json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); exit; }
function config(): array {
    $file=__DIR__.'/config.php';
    if(!is_file($file)) respond(['ok'=>false,'error'=>'Server setup is incomplete. Add config.php from the example.'],503);
    $cfg=require $file;
    if(!is_array($cfg)) respond(['ok'=>false,'error'=>'config.php must return a configuration array.'],500);
    foreach(['store_url','consumer_key','consumer_secret','admin_password_hash','data_dir'] as $key) if(empty($cfg[$key])||!is_string($cfg[$key])) respond(['ok'=>false,'error'=>'Missing configuration value: '.$key],503);
    if(!str_starts_with($cfg['store_url'],'https://')) respond(['ok'=>false,'error'=>'The WooCommerce store URL must use HTTPS.'],503);
    $target=rtrim($cfg['data_dir'],'/');$docRoot=realpath((string)($_SERVER['DOCUMENT_ROOT']??''));$resolvedTarget=false;
    if($target!==''&&$target[0]==='/'){
        $ancestor=$target;while(!is_dir($ancestor)&&dirname($ancestor)!==$ancestor)$ancestor=dirname($ancestor);$resolvedAncestor=realpath($ancestor);
        $ancestorIsPublic=$docRoot!==false&&$resolvedAncestor!==false&&($resolvedAncestor===$docRoot||str_starts_with($resolvedAncestor,rtrim($docRoot,'/').'/'));
        if(!$ancestorIsPublic){if(!is_dir($target))@mkdir($target,0700,true);$candidate=realpath($target);if($candidate!==false&&is_writable($candidate)&&!($docRoot!==false&&($candidate===$docRoot||str_starts_with($candidate,rtrim($docRoot,'/').'/'))))$resolvedTarget=$candidate;}
    }
    if($resolvedTarget===false){
        // Last-resort storage stays in this app folder but is blocked by Apache/LiteSpeed.
        $fallback=__DIR__.'/.private-data';if(!is_dir($fallback))@mkdir($fallback,0700,true);$candidate=realpath($fallback);
        if($candidate!==false&&is_dir($candidate)&&is_writable($candidate)){
            $deny="Require all denied\nOptions -Indexes\n";$index="<?php http_response_code(404); exit;\n";
            if((!is_file($candidate.'/.htaccess')||file_get_contents($candidate.'/.htaccess')!==$deny)&&file_put_contents($candidate.'/.htaccess',$deny,LOCK_EX)===false)respond(['ok'=>false,'error'=>'PHP could not protect the fallback JSON folder.'],503);
            if((!is_file($candidate.'/index.php')||file_get_contents($candidate.'/index.php')!==$index)&&file_put_contents($candidate.'/index.php',$index,LOCK_EX)===false)respond(['ok'=>false,'error'=>'PHP could not protect the fallback JSON folder.'],503);
            @chmod($candidate,0700);$resolvedTarget=$candidate;
        }
    }
    if($resolvedTarget===false)respond(['ok'=>false,'error'=>'PHP cannot create writable JSON storage. Set data_dir to a private path whose parent PHP can write, or make the sale-manager folder writable by PHP.'],503);
    @chmod($resolvedTarget,0700);$cfg['data_dir']=$resolvedTarget;
    return $cfg;
}
function body(): array { $v=json_decode((string)file_get_contents('php://input'),true);return is_array($v)?$v:[]; }
function require_auth(): void {
    if(empty($_SESSION['sale_manager_authenticated'])) respond(['ok'=>false,'error'=>'Please sign in again.'],401);
    $given=$_SERVER['HTTP_X_CSRF_TOKEN']??'';$expected=$_SESSION['sale_manager_csrf']??'';
    if(!$expected||!hash_equals($expected,$given)) respond(['ok'=>false,'error'=>'Security token expired. Refresh the page and sign in again.'],403);
}
function with_lock(array $cfg, callable $fn): mixed {
    $file=rtrim($cfg['data_dir'],DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.'manager.lock';
    $handle=fopen($file,'c');if(!$handle||!flock($handle,LOCK_EX))respond(['ok'=>false,'error'=>'Could not lock private JSON storage.'],500);
    try{return $fn($cfg);}finally{flock($handle,LOCK_UN);fclose($handle);}
}
function read_json(array $cfg,string $name): array { $path=rtrim($cfg['data_dir'],DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.$name;if(!is_file($path))return []; $raw=file_get_contents($path);$data=json_decode((string)$raw,true);return is_array($data)?$data:[]; }
function write_json(array $cfg,string $name,array $data): void { $path=rtrim($cfg['data_dir'],DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.$name;$temp=$path.'.tmp';$json=json_encode($data,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);if($json===false||file_put_contents($temp,$json,LOCK_EX)===false||!rename($temp,$path)){@unlink($temp);respond(['ok'=>false,'error'=>'Could not save the private JSON data.'],500);} @chmod($path,0600); }
function wc(array $cfg,string $method,string $path,array $query=[],?array $payload=null,bool $throwErrors=false): array {
    if(!function_exists('curl_init')){if($throwErrors)throw new RuntimeException('PHP cURL is required on this server.');respond(['ok'=>false,'error'=>'PHP cURL is required on this server.'],500);}
    $url=rtrim($cfg['store_url'],'/').'/wp-json/wc/v3/'.$path;if($query)$url.='?'.http_build_query($query);
    $ch=curl_init($url);$headers=['Accept: application/json'];if($payload!==null)$headers[]='Content-Type: application/json';
    curl_setopt_array($ch,[CURLOPT_RETURNTRANSFER=>true,CURLOPT_CUSTOMREQUEST=>$method,CURLOPT_USERPWD=>$cfg['consumer_key'].':'.$cfg['consumer_secret'],CURLOPT_HTTPAUTH=>CURLAUTH_BASIC,CURLOPT_HTTPHEADER=>$headers,CURLOPT_CONNECTTIMEOUT=>12,CURLOPT_TIMEOUT=>45,CURLOPT_POSTFIELDS=>$payload===null?null:json_encode($payload),CURLOPT_SSL_VERIFYPEER=>true,CURLOPT_SSL_VERIFYHOST=>2]);
    $raw=curl_exec($ch);$status=(int)curl_getinfo($ch,CURLINFO_RESPONSE_CODE);$err=curl_error($ch);curl_close($ch);
    if($raw===false){$error='WooCommerce connection failed: '.$err;if($throwErrors)throw new RuntimeException($error);respond(['ok'=>false,'error'=>$error],502);}
    // Some WooCommerce/security layers prepend a UTF-8 BOM to otherwise valid JSON.
    if(is_string($raw)&&str_starts_with($raw,"\xEF\xBB\xBF"))$raw=substr($raw,3);
    $data=json_decode((string)$raw,true);if($status<200||$status>=300){$reason=is_array($data)?($data['message']??''):'';$error='WooCommerce returned HTTP '.$status.($reason?': '.$reason:'');if($throwErrors)throw new RuntimeException($error);respond(['ok'=>false,'error'=>$error],502);}
    if(!is_array($data)){if($throwErrors)throw new RuntimeException('WooCommerce returned invalid JSON.');respond(['ok'=>false,'error'=>'WooCommerce returned invalid JSON.'],502);}return $data;
}
function format_item(array $entity,int $parentId,string $type,array $locks,array $drafts): array {
    $id=(int)$entity['id'];$lock=$locks[(string)$id]??['regular_price'=>$entity['regular_price']??'','sale_price'=>$entity['sale_price']??'','captured_at'=>gmdate('c')];$draft=$drafts[(string)$id]??null;
    return ['id'=>$id,'parent_id'=>$parentId,'type'=>$type,'name'=>(string)($entity['name']??''),'sku'=>(string)($entity['sku']??''),'locked_regular'=>(string)($lock['regular_price']??''),'locked_sale'=>(string)($lock['sale_price']??''),'locked_at'=>(string)($lock['captured_at']??''),'current_sale'=>(string)($entity['sale_price']??''),'pending_price'=>$draft['pending_price']??null,'updated_at'=>$draft['updated_at']??gmdate('c')];
}
function endpoint_for(array $item): string { return $item['type']==='variation'?'products/'.(int)$item['parent_id'].'/variations/'.(int)$item['id']:'products/'.(int)$item['id']; }
function same_price(string $a,string $b): bool { if($a===''||$b==='')return $a===$b;return is_numeric($a)&&is_numeric($b)&&abs((float)$a-(float)$b)<0.000001; }

$action=(string)($_GET['action']??'');$input=body();
if($action==='login'){
    $cfg=config();$password=(string)($input['password']??'');if(!password_verify($password,$cfg['admin_password_hash']))respond(['ok'=>false,'error'=>'Incorrect password.'],401);
    session_regenerate_id(true);$_SESSION['sale_manager_authenticated']=true;$_SESSION['sale_manager_csrf']=bin2hex(random_bytes(32));respond(['ok'=>true,'csrf'=>$_SESSION['sale_manager_csrf']]);
}
if($action==='logout'){$_SESSION=[];session_destroy();respond(['ok'=>true]);}
require_auth();$cfg=config();
if($action==='list'){
    $items=with_lock($cfg,function($c){$drafts=read_json($c,'drafts.json');$locks=read_json($c,'locks.json');$history=read_json($c,'history.json');$archived=read_json($c,'archived.json');$visible=[];$changed=false;foreach($drafts as$id=>$item){$hasPending=array_key_exists('pending_price',$item)&&$item['pending_price']!==null;$allowChange=!empty($item['allow_change']);if(!$hasPending&&!$allowChange&&isset($archived[(string)$id])){unset($drafts[$id]);$changed=true;continue;}$lock=$locks[(string)$id]??[];$lockedSale=(string)($lock['sale_price']??$item['locked_sale']??'');$current=(string)($item['current_sale']??'');if(!$hasPending&&!$allowChange&&!same_price($lockedSale,$current)){$archived[(string)$id]=['product_id'=>(int)($item['id']??$id),'archived_at'=>gmdate('c'),'status'=>'detected'];$tracked=false;foreach($history as$event){if((string)($event['product_id']??'')===(string)$id&&in_array($event['status']??'', ['success','detected'],true)){$tracked=true;break;}}if(!$tracked)$history[]=['product_id'=>(int)($item['id']??$id),'parent_id'=>(int)($item['parent_id']??$id),'type'=>(string)($item['type']??'product'),'name'=>(string)($item['name']??''),'sku'=>(string)($item['sku']??''),'cost_price'=>(string)($item['cost_price']??''),'locked_regular'=>(string)($item['locked_regular']??''),'locked_sale'=>$lockedSale,'new_sale_price'=>$current,'uploaded_at'=>(string)($item['updated_at']??gmdate('c')),'status'=>'detected','error'=>'','note'=>'Current sale price differs from the first locked price. Hidden from the main list; this change was not submitted by this page.'];unset($drafts[$id]);$changed=true;continue;}$visible[]=$item;}if($changed){write_json($c,'drafts.json',$drafts);write_json($c,'archived.json',$archived);write_json($c,'history.json',$history);}return $visible;});respond(['ok'=>true,'items'=>$items]);
}
if($action==='history'){
    $items=with_lock($cfg,fn($c)=>array_values(read_json($c,'history.json')));usort($items,fn($a,$b)=>strcmp((string)($b['uploaded_at']??''),(string)($a['uploaded_at']??'')));respond(['ok'=>true,'items'=>$items]);
}
if($action==='clear-history'){
    $result=with_lock($cfg,function($c){$source=rtrim($c['data_dir'],DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.'history.json';$history=is_file($source)?read_json($c,'history.json'):[];$backup='history-backup-'.gmdate('Ymd-His').'-'.bin2hex(random_bytes(3)).'.json';$backupPath=rtrim($c['data_dir'],DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR.$backup;if(is_file($source)){if(!copy($source,$backupPath))respond(['ok'=>false,'error'=>'Could not back up upload history; nothing was cleared.'],500);@chmod($backupPath,0600);}else{write_json($c,$backup,$history);}write_json($c,'history.json',[]);return ['count'=>count($history),'backup'=>$backup];});respond(['ok'=>true,'message'=>'Upload history cleared. A private server backup was saved.','cleared_count'=>$result['count'],'backup'=>$result['backup']]);
}
if($action==='reopen'){
    $id=(string)filter_var($input['id']??null,FILTER_VALIDATE_INT);if($id===''||$id==='0')respond(['ok'=>false,'error'=>'Invalid product.'],422);
    $item=with_lock($cfg,function($c)use($id){$drafts=read_json($c,'drafts.json');if(isset($drafts[$id]))return $drafts[$id];$history=read_json($c,'history.json');$candidate=null;foreach($history as$row){if((string)($row['product_id']??'')===$id&&in_array($row['status']??'', ['success','detected'],true)&&($candidate===null||strcmp((string)($row['uploaded_at']??''),(string)($candidate['uploaded_at']??''))>0))$candidate=$row;}if($candidate===null)respond(['ok'=>false,'error'=>'No uploaded product record was found in history.'],404);$draft=['id'=>(int)$id,'parent_id'=>(int)($candidate['parent_id']??$id),'type'=>(string)($candidate['type']??'product'),'name'=>(string)($candidate['name']??''),'sku'=>(string)($candidate['sku']??''),'locked_regular'=>(string)($candidate['locked_regular']??''),'locked_sale'=>(string)($candidate['locked_sale']??''),'locked_at'=>(string)($candidate['locked_at']??''),'current_sale'=>(string)($candidate['new_sale_price']??''),'pending_price'=>null,'cost_price'=>(string)($candidate['cost_price']??''),'allow_change'=>true,'updated_at'=>gmdate('c')];$drafts[$id]=$draft;write_json($c,'drafts.json',$drafts);$archived=read_json($c,'archived.json');unset($archived[$id]);write_json($c,'archived.json',$archived);return $draft;});respond(['ok'=>true,'item'=>$item]);
}
if($action==='lookup'){
    $sku=trim((string)($input['sku']??''));if($sku===''||strlen($sku)>128)respond(['ok'=>false,'error'=>'Enter a valid product SKU/barcode.'],422);
    $products=wc($cfg,'GET','products',['sku'=>$sku,'per_page'=>100]);if(!$products)respond(['ok'=>false,'error'=>'No WooCommerce product matched this SKU. Set the barcode as the product SKU, then try again.'],404);
    $product=$products[0];$entities=[[$product,(int)$product['id'],'product']];
    if(($product['type']??'')==='variable'){
        for($page=1;$page<=100;$page++){$vars=wc($cfg,'GET','products/'.(int)$product['id'].'/variations',['per_page'=>100,'page'=>$page]);foreach($vars as $v)$entities[]=[$v,(int)$product['id'],'variation'];if(count($vars)<100)break;}
    }
    $result=with_lock($cfg,function($c)use($entities){$locks=read_json($c,'locks.json');$drafts=read_json($c,'drafts.json');$history=read_json($c,'history.json');$archived=read_json($c,'archived.json');$out=[];$hidden=0;$changed=false;foreach($entities as[$entity,$parent,$type]){$id=(string)(int)$entity['id'];if(!isset($locks[$id]))$locks[$id]=['regular_price'=>(string)($entity['regular_price']??''),'sale_price'=>(string)($entity['sale_price']??''),'captured_at'=>gmdate('c')];if(isset($archived[$id])&&empty($drafts[$id]['allow_change'])){$hidden++;continue;}$liveSale=(string)($entity['sale_price']??'');$lockedSale=(string)($locks[$id]['sale_price']??'');$hasPending=isset($drafts[$id])&&array_key_exists('pending_price',$drafts[$id])&&$drafts[$id]['pending_price']!==null;$allowChange=!empty($drafts[$id]['allow_change']);if(!$hasPending&&!$allowChange&&!same_price($lockedSale,$liveSale)){$archived[$id]=['product_id'=>(int)$id,'archived_at'=>gmdate('c'),'status'=>'detected'];$draft=$drafts[$id]??format_item($entity,$parent,$type,$locks,[]);$tracked=false;foreach($history as$event){if((string)($event['product_id']??'')===$id&&in_array($event['status']??'', ['success','detected'],true)){$tracked=true;break;}}if(!$tracked)$history[]=['product_id'=>(int)$id,'parent_id'=>$parent,'type'=>$type,'name'=>(string)($entity['name']??''),'sku'=>(string)($entity['sku']??''),'cost_price'=>(string)($draft['cost_price']??''),'locked_regular'=>(string)($locks[$id]['regular_price']??''),'locked_sale'=>$lockedSale,'new_sale_price'=>$liveSale,'uploaded_at'=>gmdate('c'),'status'=>'detected','error'=>'','note'=>'Current sale price differs from the first locked price. Hidden from the main list; this change was not submitted by this page.'];unset($drafts[$id]);$hidden++;$changed=true;continue;}if(!isset($drafts[$id]))$drafts[$id]=format_item($entity,$parent,$type,$locks,[]);else{$drafts[$id]['current_sale']=$liveSale;$drafts[$id]['name']=(string)($entity['name']??'');$drafts[$id]['sku']=(string)($entity['sku']??'');$drafts[$id]['updated_at']=gmdate('c');}$out[]=$drafts[$id];}write_json($c,'locks.json',$locks);write_json($c,'drafts.json',$drafts);if($changed){write_json($c,'archived.json',$archived);write_json($c,'history.json',$history);}return ['items'=>$out,'hidden_count'=>$hidden];});respond(['ok'=>true,'items'=>$result['items'],'hidden_count'=>$result['hidden_count']]);
}
if($action==='suggest-price'){
    $id=(string)filter_var($input['id']??null,FILTER_VALIDATE_INT);if($id===''||$id==='0')respond(['ok'=>false,'error'=>'Invalid product.'],422);
    $basisType='';$item=with_lock($cfg,function($c)use($id,&$basisType){$drafts=read_json($c,'drafts.json');if(!isset($drafts[$id]))respond(['ok'=>false,'error'=>'Scan or reopen this product before suggesting a price.'],404);$cost=trim((string)($drafts[$id]['cost_price']??''));if($cost===''||!is_numeric($cost))respond(['ok'=>false,'error'=>'Enter and save your cost first. Cost is required for AI Suggest.'],422);$lockedSale=trim((string)($drafts[$id]['locked_sale']??''));$lockedRegular=trim((string)($drafts[$id]['locked_regular']??''));$basisType=$lockedSale!==''?'sale':'regular';$basis=$basisType==='sale'?$lockedSale:$lockedRegular;if($basis===''||!is_numeric($basis)||(float)$basis<=0)respond(['ok'=>false,'error'=>'This product has no locked sale or regular price to use for the 25% discount.'],422);$suggested=number_format(round((float)$basis*0.75,2),2,'.','');if((float)$suggested<=0)respond(['ok'=>false,'error'=>'The suggested price must be greater than zero.'],422);$drafts[$id]['pending_price']=$suggested;unset($drafts[$id]['allow_change']);$drafts[$id]['updated_at']=gmdate('c');write_json($c,'drafts.json',$drafts);return $drafts[$id];});respond(['ok'=>true,'item'=>$item,'basis_type'=>$basisType,'discount_percent'=>25]);
}
if($action==='save-draft'){
    $id=(string)filter_var($input['id']??null,FILTER_VALIDATE_INT);$price=trim((string)($input['pending_price']??''));if($id===''||$id==='0')respond(['ok'=>false,'error'=>'Invalid product.'],422);
    if($price!==''&&(!preg_match('/^\d{1,9}(?:\.\d{1,6})?$/',$price)||(float)$price<=0))respond(['ok'=>false,'error'=>'Enter a valid positive price using digits and a decimal point.'],422);
    $item=with_lock($cfg,function($c)use($id,$price){$drafts=read_json($c,'drafts.json');if(!isset($drafts[$id]))respond(['ok'=>false,'error'=>'Scan this product again before saving a price.'],404);$drafts[$id]['pending_price']=$price;unset($drafts[$id]['allow_change']);$drafts[$id]['updated_at']=gmdate('c');write_json($c,'drafts.json',$drafts);return $drafts[$id];});respond(['ok'=>true,'item'=>$item]);
}
if($action==='save-cost'){
    $id=(string)filter_var($input['id']??null,FILTER_VALIDATE_INT);$cost=trim((string)($input['cost_price']??''));if($id===''||$id==='0')respond(['ok'=>false,'error'=>'Invalid product.'],422);
    if($cost!==''&&!preg_match('/^\d{1,9}(?:\.\d{1,6})?$/',$cost))respond(['ok'=>false,'error'=>'Enter cost as digits with an optional decimal point.'],422);
    $item=with_lock($cfg,function($c)use($id,$cost){$drafts=read_json($c,'drafts.json');if(!isset($drafts[$id]))respond(['ok'=>false,'error'=>'Scan this product again before saving cost.'],404);$drafts[$id]['cost_price']=$cost;$drafts[$id]['updated_at']=gmdate('c');write_json($c,'drafts.json',$drafts);return $drafts[$id];});respond(['ok'=>true,'item'=>$item]);
}
if($action==='publish'){
    $drafts=with_lock($cfg,fn($c)=>read_json($c,'drafts.json'));$ready=array_filter($drafts,fn($item)=>array_key_exists('pending_price',$item)&&$item['pending_price']!==null);if(!$ready)respond(['ok'=>false,'error'=>'There are no sale prices saved as drafts.'],422);
    $markedBigDays=[];$updated=[];$errors=[];$events=[];foreach($ready as$id=>$item){$parentId=(int)($item['parent_id']??$item['id']);$productId=($item['type']??'')==='variation'?$parentId:(int)$item['id'];$event=['product_id'=>(int)$item['id'],'parent_id'=>$parentId,'type'=>(string)($item['type']??'product'),'name'=>(string)($item['name']??''),'sku'=>(string)($item['sku']??''),'locked_regular'=>(string)($item['locked_regular']??''),'locked_sale'=>(string)($item['locked_sale']??''),'new_sale_price'=>(string)$item['pending_price'],'big_days_sale'=>true,'big_days_sale_meta_key'=>'_yana_big_days_sale','uploaded_at'=>gmdate('c')];try{if(!isset($markedBigDays[$productId])){wc($cfg,'PUT','products/'.$productId,[],['meta_data'=>[['key'=>'_yana_big_days_sale','value'=>'yes']]],true);$verified=wc($cfg,'GET','products/'.$productId);$flag=false;foreach(($verified['meta_data']??[])as$meta){if(($meta['key']??'')==='_yana_big_days_sale'&&($meta['value']??'')==='yes'){$flag=true;break;}}if(!$flag)throw new RuntimeException('WooCommerce did not save the Big Days Sale checkbox. Sale price was not published.');$markedBigDays[$productId]=true;}wc($cfg,'PUT',endpoint_for($item),[],['sale_price'=>(string)$item['pending_price']],true);$updated[]=(string)$id;$events[]=$event+['status'=>'success','error'=>''];}catch(Throwable $e){$error=$e->getMessage();$errors[]=(string)($item['name']??$id).': '.$error;$events[]=$event+['status'=>'failed','error'=>$error];}}
    $remaining=with_lock($cfg,function($c)use($updated,$events,$ready){$drafts=read_json($c,'drafts.json');$archived=read_json($c,'archived.json');foreach($updated as$id){unset($drafts[$id]);$archived[(string)$id]=['product_id'=>(int)$id,'archived_at'=>gmdate('c'),'status'=>'success'];}write_json($c,'drafts.json',$drafts);write_json($c,'archived.json',$archived);$history=read_json($c,'history.json');foreach($events as$event){$source=$ready[(string)$event['product_id']]??[];$event['cost_price']=(string)($source['cost_price']??'');$history[]=$event;}if(count($history)>3000)$history=array_slice($history,-3000);write_json($c,'history.json',$history);return array_values($drafts);});
    respond(['ok'=>true,'updated_ids'=>$updated,'remaining'=>$remaining,'failed'=>(bool)$errors,'message'=>count($updated).' price(s) uploaded.'.($errors?' Some items failed: '.implode(' | ',$errors):'')]);
}
respond(['ok'=>false,'error'=>'Unknown action.'],404);
