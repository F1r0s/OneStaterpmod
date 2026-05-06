<?php
$contactValue = $_POST['contact'] ?? $_GET['contact'] ?? null;

$isAjax = (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest');

if ($contactValue === null || $contactValue === '') {
  if ($isAjax) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'empty']);
    exit;
  }

  header('Location: /index.html');
  exit;
}

$contact = trim($contactValue);
$is_email = preg_match('/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/i', $contact);
$is_phone = preg_match('/^\d{7,15}$/', $contact);

if (!$is_email && !$is_phone) {
  if ($isAjax) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'invalid']);
    exit;
  }

  header('Location: /index.html?newsletter=error');
  exit;
}

$file = __DIR__ . DIRECTORY_SEPARATOR . 'leadsonestate.txt';
$entry = $contact . PHP_EOL;

if (file_put_contents($file, $entry, FILE_APPEND | LOCK_EX) === false) {
  if ($isAjax) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'error' => 'write_failed']);
    exit;
  }

  header('Location: /index.html?newsletter=error');
  exit;
}

if ($isAjax) {
  header('Content-Type: application/json');
  echo json_encode(['success' => true]);
  exit;
}

header('Location: /index.html?newsletter=success');
exit;
?>