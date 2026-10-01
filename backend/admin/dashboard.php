<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/bootstrap.php';
require_admin();
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Dashboard | Wood & Panel Admin</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
  <nav class="navbar navbar-expand bg-white border-bottom">
    <div class="container-fluid">
      <span class="navbar-brand fw-bold">Wood & Panel</span>
      <span class="badge text-bg-success"><?= e($_SESSION['admin_role'] ?? 'admin') ?></span>
    </div>
  </nav>
  <main class="container py-4">
    <h1 class="h3">Dashboard</h1>
    <div class="row g-3 mt-2">
      <div class="col-md-3"><div class="card"><div class="card-body"><div class="text-muted">Articles</div><div class="h4">0</div></div></div></div>
      <div class="col-md-3"><div class="card"><div class="card-body"><div class="text-muted">Magazines</div><div class="h4">0</div></div></div></div>
      <div class="col-md-3"><div class="card"><div class="card-body"><div class="text-muted">Users</div><div class="h4">0</div></div></div></div>
      <div class="col-md-3"><div class="card"><div class="card-body"><div class="text-muted">Downloads</div><div class="h4">0</div></div></div></div>
    </div>
  </main>
</body>
</html>
