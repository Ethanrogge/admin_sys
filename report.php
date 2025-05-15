<?php
$client_ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$hostname = $_GET['hostname'] ?? 'unknown';
$line = $hostname . ' ' . $client_ip . "\n";
file_put_contents('/var/log/' . $hostname . '.txt', $line, FILE_APPEND | LOCK_EX);
header('Content-Type: text/plain');
echo "OK\n";
?>
