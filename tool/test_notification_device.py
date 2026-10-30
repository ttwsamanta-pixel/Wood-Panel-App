"""Send one test only to the connected debug app, never to an edition topic.

Private credentials and device token are kept in memory and never printed.
Requires PHP with OpenSSL/cURL, adb, and an existing Firebase device registration.
"""
import argparse
import html
import json
import subprocess
import urllib.request
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--credentials', required=True)
parser.add_argument('--adb', required=True)
parser.add_argument('--php', required=True)
parser.add_argument('--edition', choices=['europe', 'usa'], default='europe')
parser.add_argument('--text-only', action='store_true')
args = parser.parse_args()
raw = subprocess.check_output([args.adb, 'shell', 'run-as', 'com.example.wood_panel_app',
                               'cat', 'shared_prefs/com.google.android.gms.appid.xml'])
tokens = []
for node in ET.fromstring(raw).findall('string'):
    if '|T|' in node.attrib.get('name', ''):
        try:
            value = json.loads(node.text or '{}')
            if value.get('token'):
                tokens.append(value['token'])
        except ValueError:
            pass
if len(tokens) != 1:
    raise SystemExit('Expected exactly one Firebase registration on the connected app.')
site = 'https://www.woodandpanel.' + ('com' if args.edition == 'europe' else 'us')
request = urllib.request.Request(site + '/wp-json/wp/v2/posts?per_page=1&_embed=wp:featuredmedia', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(request, timeout=30) as response:
    post = json.load(response)[0]
message = {'token': tokens[0], 'notification': {'title': ('Text test: ' if args.text_only else 'Image test: ') + html.unescape(post['title']['rendered']),
           'body': 'Wood & Panel notification test on this phone only.'},
           'data': {'edition': args.edition, 'article_id': str(post['id'])}}
if not args.text_only:
    media = post.get('_embedded', {}).get('wp:featuredmedia', [{}])[0]
    sizes = media.get('media_details', {}).get('sizes', {})
    image = (sizes.get('medium_large') or sizes.get('medium') or {}).get('source_url')
    if not image or not image.startswith('https://'):
        raise SystemExit('Latest article has no suitable featured image.')
    message['android'] = {'notification': {'image': image}}
    message['apns'] = {'payload': {'aps': {'mutable-content': 1}}, 'fcm_options': {'image': image}}
    message['data']['image_url'] = image
php = r'''
$input = json_decode(stream_get_contents(STDIN), true);
$credentials = json_decode(file_get_contents($input['credentials']), true);
$encode = static fn($value) => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
$now = time();
$jwt = $encode(json_encode(['alg'=>'RS256','typ'=>'JWT'])) . '.' . $encode(json_encode([
 'iss'=>$credentials['client_email'], 'scope'=>'https://www.googleapis.com/auth/firebase.messaging',
 'aud'=>'https://oauth2.googleapis.com/token','iat'=>$now,'exp'=>$now+3600]));
if (!openssl_sign($jwt, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256)) { fwrite(STDERR, 'Signing failed'); exit(1); }
function request($url, $body, $headers) {
 $curl = curl_init($url);
 curl_setopt_array($curl, [CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>$body,CURLOPT_HTTPHEADER=>$headers,CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>30]);
 $response = curl_exec($curl); $status = curl_getinfo($curl, CURLINFO_HTTP_CODE); curl_close($curl);
 if ($status !== 200) { fwrite(STDERR, 'Firebase HTTP status ' . $status); exit(1); }
 return json_decode($response, true);
}
$auth = request('https://oauth2.googleapis.com/token', http_build_query(['grant_type'=>'urn:ietf:params:oauth:grant-type:jwt-bearer','assertion'=>$jwt.'.'.$encode($signature)]), ['Content-Type: application/x-www-form-urlencoded']);
request('https://fcm.googleapis.com/v1/projects/'.$credentials['project_id'].'/messages:send', json_encode(['message'=>$input['message']]), ['Content-Type: application/json','Authorization: Bearer '.$auth['access_token']]);
echo "Firebase accepted the single-device test.\n";
'''
subprocess.run([args.php, '-r', php], input=json.dumps({'credentials': args.credentials, 'message': message}).encode(), check=True)
