<?php
$contactValue = $_POST['contact'] ?? $_GET['contact'] ?? null;

if ($contactValue === null || $contactValue === '') {
  header('Location: /index.html');
  exit;
}

$contact = trim($contactValue);
$is_email = preg_match('/^[A-Za-z0-9._%+-]+@(gmail\.com|googlemail\.com)$/i', $contact);
$is_phone = preg_match('/^\d{7,15}$/', $contact);

if (!$is_email && !$is_phone) {
  header('Location: /index.html?newsletter=error');
  exit;
}

$file = __DIR__ . DIRECTORY_SEPARATOR . 'leadsonestate.txt';
$entry = $contact . PHP_EOL;

if (file_put_contents($file, $entry, FILE_APPEND | LOCK_EX) === false) {
  header('Location: /index.html?newsletter=error');
  exit;
}

header('Location: /index.html?newsletter=success');
exit;
?>