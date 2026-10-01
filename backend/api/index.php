<?php
declare(strict_types=1);

require_once __DIR__ . '/../src/bootstrap.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$route = preg_replace('#^/api#', '', $path);

try {
    if ($method === 'GET' && $route === '/app/settings') {
        json_success([
            'app_name' => 'Wood & Panel',
            'maintenance_mode' => false,
            'minimum_version' => '0.1.0',
            'recommended_version' => '0.1.0',
            'wordpress_base_url' => 'https://www.woodandpanel.com',
        ]);
    }

    if ($method === 'POST' && $route === '/app/newsletter') {
        $input = json_input();
        $email = filter_var($input['email'] ?? '', FILTER_VALIDATE_EMAIL);
        if (!$email) {
            json_error('A valid email address is required.', 422);
        }
        $stmt = db()->prepare(
            'INSERT INTO newsletter_subscribers (email, name, status, created_at, updated_at)
             VALUES (:email, :name, :status, NOW(), NOW())
             ON DUPLICATE KEY UPDATE name = VALUES(name), status = VALUES(status), updated_at = NOW()'
        );
        $stmt->execute([
            'email' => $email,
            'name' => trim((string)($input['name'] ?? '')),
            'status' => 'active',
        ]);
        json_success(null, 'Newsletter subscription saved.');
    }

    if ($method === 'POST' && $route === '/app/contact') {
        $input = json_input();
        $name = trim((string)($input['name'] ?? ''));
        $email = filter_var($input['email'] ?? '', FILTER_VALIDATE_EMAIL);
        $message = trim((string)($input['message'] ?? ''));
        if ($name === '' || !$email || $message === '') {
            json_error('Name, email, and message are required.', 422);
        }
        $stmt = db()->prepare(
            'INSERT INTO contact_messages (name, email, subject, message, status, created_at, updated_at)
             VALUES (:name, :email, :subject, :message, :status, NOW(), NOW())'
        );
        $stmt->execute([
            'name' => $name,
            'email' => $email,
            'subject' => trim((string)($input['subject'] ?? '')),
            'message' => $message,
            'status' => 'new',
        ]);
        json_success(null, 'Contact message saved.');
    }

    json_error('Endpoint not found.', 404);
} catch (Throwable $exception) {
    error_log($exception->getMessage());
    json_error('Something went wrong. Please try again later.', 500);
}
