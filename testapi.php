<?php

declare(strict_types=1);

$calendarPath = __DIR__ . DIRECTORY_SEPARATOR . 'test.ics';

if (!is_file($calendarPath)) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'test.ics not found'], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit(1);
}

$events = parseIcsEvents($calendarPath);
$targetWeekStart = findTargetWeekStart($events);
$responseEvents = buildApiEvents($events, $targetWeekStart);

header('Content-Type: application/json; charset=utf-8');
echo json_encode(
    [
        'timestamp' => nowIso(),
        'events' => $responseEvents,
    ],
    JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
);

function parseIcsEvents(string $path): array
{
    $rawLines = file($path, FILE_IGNORE_NEW_LINES);
    if ($rawLines === false) {
        throw new RuntimeException('Unable to read test.ics');
    }

    $lines = unfoldIcsLines($rawLines);
    $events = [];
    $currentEvent = null;

    foreach ($lines as $line) {
        $trimmedLine = rtrim($line, "\r\n");

        if ($trimmedLine === 'BEGIN:VEVENT') {
            $currentEvent = [];
            continue;
        }

        if ($trimmedLine === 'END:VEVENT') {
            if ($currentEvent !== null) {
                $events[] = normalizeRawEvent($currentEvent);
            }
            $currentEvent = null;
            continue;
        }

        if ($currentEvent === null) {
            continue;
        }

        $separatorPosition = strpos($trimmedLine, ':');
        if ($separatorPosition === false) {
            continue;
        }

        $rawKey = substr($trimmedLine, 0, $separatorPosition);
        $value = substr($trimmedLine, $separatorPosition + 1);
        $key = strtoupper(explode(';', $rawKey, 2)[0]);
        $currentEvent[$key] = unescapeIcsText($value);
    }

    return $events;
}

function unfoldIcsLines(array $lines): array
{
    $result = [];

    foreach ($lines as $line) {
        if ($result !== [] && ($line !== '') && (($line[0] ?? '') === ' ' || ($line[0] ?? '') === "\t")) {
            $result[array_key_last($result)] .= substr($line, 1);
            continue;
        }

        $result[] = $line;
    }

    return $result;
}

function unescapeIcsText(string $value): string
{
    return str_replace(
        ['\\,', '\\;', '\\n', '\\N'],
        [',', ';', "\n", "\n"],
        $value
    );
}

function normalizeRawEvent(array $rawEvent): array
{
    $summary = trim((string) ($rawEvent['SUMMARY'] ?? ''));
    $description = normalizeNullableText($rawEvent['DESCRIPTION'] ?? null);
    $location = normalizeNullableText($rawEvent['LOCATION'] ?? null);
    $uid = trim((string) ($rawEvent['UID'] ?? md5(json_encode($rawEvent))));
    $start = parseIcsDate((string) ($rawEvent['DTSTART'] ?? ''));
    $end = parseIcsDate((string) ($rawEvent['DTEND'] ?? ''));
    $dtstamp = parseIcsTimestamp((string) ($rawEvent['DTSTAMP'] ?? '')) ?? $end ?? $start;
    $lecturer = deriveLecturer($summary);

    return [
        'uid' => $uid,
        'id' => uuidFromString($uid),
        'summary' => $summary,
        'description' => $description,
        'sourceLocation' => $location,
        'location' => deriveLocation($summary, $location),
        'lecturer' => $lecturer,
        'category' => deriveCategory($summary, $description, $lecturer),
        'start' => $start,
        'end' => $end,
        'dtstamp' => $dtstamp,
    ];
}

function parseIcsDate(string $value): ?DateTimeImmutable
{
    $value = trim($value);
    if ($value === '') {
        return null;
    }

    $timezone = new DateTimeZone('Europe/Berlin');
    $date = DateTimeImmutable::createFromFormat('Ymd\THis', $value, $timezone);

    return $date ?: null;
}

function parseIcsTimestamp(string $value): ?DateTimeImmutable
{
    $value = trim($value);
    if ($value === '') {
        return null;
    }

    $utc = new DateTimeZone('UTC');
    $date = DateTimeImmutable::createFromFormat('Ymd\THis\Z', $value, $utc);

    return $date ?: null;
}

function normalizeNullableText(?string $value): ?string
{
    if ($value === null) {
        return null;
    }

    $trimmed = trim($value);
    return $trimmed === '' ? null : $trimmed;
}

function deriveLecturer(string $summary): ?string
{
    $normalizedSummary = ltrim(trim($summary), '* ');
    $tokens = preg_split('/\s+/', $normalizedSummary) ?: [];

    if (count($tokens) < 2) {
        return null;
    }

    if (!preg_match('/^[A-Z0-9]{3}$/', $tokens[0])) {
        return null;
    }

    return preg_match('/^[A-Z]{3}$/', $tokens[1]) === 1 ? $tokens[1] : null;
}

function deriveLocation(string $summary, ?string $fallbackLocation): ?string
{
    $normalizedSummary = ltrim(trim($summary), '* ');
    $tokens = preg_split('/\s+/', $normalizedSummary) ?: [];
    $lastToken = $tokens === [] ? null : end($tokens);

    if (is_string($lastToken) && str_starts_with(strtoupper($lastToken), 'P-')) {
        if (preg_match('/^P-(2\d{2})$/i', $lastToken, $roomMatch) === 1) {
            return 'Raum ' . $roomMatch[1];
        }

        $substrings = preg_split('/[.]/', $lastToken) ?: [];
        $lastSubstring = $substrings === [] ? null : end($substrings);
        if (is_string($lastSubstring) && preg_match('/^[A-Z]+$/', $lastSubstring) === 1) {
            return $lastSubstring[0] . '-Pool';
        }
    }

    return $fallbackLocation;
}

function deriveCategory(string $summary, ?string $description, ?string $lecturer): ?string
{
    $normalizedSummary = mb_strtolower($summary, 'UTF-8');
    $normalizedDescription = $description !== null ? mb_strtolower($description, 'UTF-8') : null;

    if (str_contains($normalizedSummary, 'sommerfest')) {
        return 'bib-event';
    }

    if (str_contains($normalizedSummary, 'ferien') || str_contains($normalizedSummary, 'brückentag') || str_contains($normalizedSummary, 'brueckentag')) {
        return 'ferien';
    }

    if ($normalizedDescription !== null && str_contains($normalizedDescription, 'ferien')) {
        return 'ferien';
    }

    if (str_starts_with(ltrim($summary), '*')) {
        return 'klausur';
    }

    if ($lecturer === null) {
        return 'selbstlernzeit';
    }

    return null;
}

function findTargetWeekStart(array $events): DateTimeImmutable
{
    return new DateTimeImmutable('2026-07-13T00:00:00+02:00');
}

function buildApiEvents(array $events, DateTimeImmutable $targetWeekStart): array
{
    $targetWeekEnd = $targetWeekStart->modify('+5 days');
    $mondayEvents = [];
    $fridayIdeEvents = [];
    $baseEvents = [];

    foreach ($events as $event) {
        $start = $event['start'];
        if (!$start instanceof DateTimeImmutable) {
            continue;
        }

        $isTargetWeek = $start >= $targetWeekStart && $start < $targetWeekEnd->modify('+1 day');
        if ($isTargetWeek && (int) $start->format('N') === 1) {
            $mondayEvents[] = $event;
        }
        if ($isTargetWeek && (int) $start->format('N') === 5 && str_starts_with($event['summary'], 'IDE')) {
            $fridayIdeEvents[] = $event;
        }

        $baseEvents[$event['uid']] = $event;
    }

    usort($mondayEvents, fn (array $left, array $right) => $left['start'] <=> $right['start']);
    usort($fridayIdeEvents, fn (array $left, array $right) => $left['start'] <=> $right['start']);

    $changedSource = $mondayEvents[0] ?? null;
    $deletedSource = $fridayIdeEvents[1] ?? $fridayIdeEvents[0] ?? null;

    if ($changedSource !== null) {
        unset($baseEvents[$changedSource['uid']]);
    }
    if ($deletedSource !== null) {
        unset($baseEvents[$deletedSource['uid']]);
    }

    $apiEvents = array_map('toApiEvent', array_values($baseEvents));

    if ($changedSource !== null) {
        $changedStart = $targetWeekStart->setTime(11, 30);
        $changedEnd = $targetWeekStart->setTime(13, 0);
        $changedEvent = $changedSource;
        $changedEvent['start'] = $changedStart;
        $changedEvent['end'] = $changedEnd;
        $changedEvent['location'] = 'G-Pool';
        $changedEvent['label'] = 'geaendert';
        $changedEvent['updatedAt'] = nowIso();
        $changedEvent['originalEvent'] = originalEventPayload($changedSource);
        $apiEvents[] = toApiEvent($changedEvent);
    }

    if ($deletedSource !== null) {
        $deletedEvent = $deletedSource;
        $deletedEvent['label'] = 'geloescht';
        $deletedEvent['updatedAt'] = nowIso();
        $deletedEvent['originalEvent'] = originalEventPayload($deletedSource);
        $apiEvents[] = toApiEvent($deletedEvent);
    }

    $newStart = $targetWeekStart->modify('+3 days')->setTime(11, 30);
    $newEnd = $targetWeekStart->modify('+3 days')->setTime(13, 0);
    $newSummary = 'OOP BCH P-225';
    $newLecturer = deriveLecturer($newSummary);
    $apiEvents[] = toApiEvent(
        [
            'uid' => 'testapi-new-oop-' . $targetWeekStart->format('Ymd'),
            'id' => uuidFromString('testapi-new-oop-' . $targetWeekStart->format('Ymd')),
            'summary' => $newSummary,
            'description' => null,
            'sourceLocation' => null,
            'location' => deriveLocation($newSummary, null),
            'lecturer' => $newLecturer,
            'category' => deriveCategory($newSummary, null, $newLecturer),
            'start' => $newStart,
            'end' => $newEnd,
            'dtstamp' => new DateTimeImmutable('now', new DateTimeZone('UTC')),
            'label' => 'neu',
        ]
    );

    usort(
        $apiEvents,
        fn (array $left, array $right) => strcmp((string) ($left['start'] ?? ''), (string) ($right['start'] ?? ''))
    );

    return $apiEvents;
}

function toApiEvent(array $event): array
{
    $payload = [
        'id' => $event['id'],
        'summary' => $event['summary'],
        'description' => $event['description'] ?? null,
        'start' => formatDate($event['start'] ?? null),
        'end' => formatDate($event['end'] ?? null),
        'location' => $event['location'] ?? null,
        'lecturer' => $event['lecturer'] ?? null,
        'category' => $event['category'] ?? null,
        'label' => $event['label'] ?? null,
        'updatedAt' => $event['updatedAt'] ?? null,
    ];

    if (isset($event['originalEvent'])) {
        $payload['originalEvent'] = $event['originalEvent'];
    }

    return $payload;
}

function originalEventPayload(array $event): array
{
    return [
        'summary' => $event['summary'],
        'description' => $event['description'] ?? null,
        'start' => formatDate($event['start'] ?? null),
        'end' => formatDate($event['end'] ?? null),
        'location' => $event['location'] ?? null,
    ];
}

function formatDate(?DateTimeImmutable $date): ?string
{
    return $date?->format(DateTimeInterface::ATOM);
}

function nowIso(): string
{
    return (new DateTimeImmutable('now'))->format(DateTimeInterface::ATOM);
}

function uuidFromString(string $value): string
{
    $hash = md5($value);

    return sprintf(
        '%08s-%04s-%04s-%04s-%12s',
        substr($hash, 0, 8),
        substr($hash, 8, 4),
        substr($hash, 12, 4),
        substr($hash, 16, 4),
        substr($hash, 20, 12)
    );
}
