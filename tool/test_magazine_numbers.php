<?php
define('ABSPATH', __DIR__);
function wpam_settings(): array {
 return ['magazine_highlights' => [['readUrl'=>'https://example.com/issue/', 'points'=>['Cover story', 'New materials']]]];
}
require __DIR__ . '/../wordpress/wood-panel-app-manager/includes/rest.php';
foreach (range(1,12) as $month) {
 $items=wpam_magazine_details([['readUrl'=>'https://example.com/issue/index.html','date'=>sprintf('2026-%02d-01',$month)]]);
 if ($items[0]['volume'] !== '18' || $items[0]['issueNumber'] !== (string)ceil($month/2) || count($items[0]['highlights']) !== 2) throw new RuntimeException('Magazine mapping failed');
}
$items=wpam_magazine_details([['readUrl'=>'https://example.com/other/','date'=>'2025-12-01']]);
if ($items[0]['volume'] !== '17' || $items[0]['highlights'] !== []) throw new RuntimeException('Unmatched issue failed');
echo "Magazine numbering and conditional highlights passed.\n";
