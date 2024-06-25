<?php
$url = 'https://writingforbusyreaders.com/ai';
$html = file_get_contents($url);

// Load HTML content into DOMDocument
$dom = new DOMDocument();
libxml_use_internal_errors(true);
$dom->loadHTML($html);
libxml_clear_errors();

// Extract the specific div content
$xpath = new DOMXPath($dom);
$div = $xpath->query('//div[contains(@class, "et_pb_row et_pb_row_3")]')->item(0);

// Print the extracted div
if ($div) {
    echo $dom->saveHTML($div);
} else {
    echo "Content not found.";
}
?>
