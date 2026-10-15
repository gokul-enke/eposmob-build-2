# VPS process tracking: what was installed and verified

**Prepared:** 15 October 2026  
**VPS state last checked:** 9 October 2026  
**Scope:** production VPS tracking work completed on 8 October 2026 and follow-up observations through the morning of 9 October. This is a record of that work, not a live status check.

## Why tracking was added

After the VPS showed unusually high CPU usage, we wanted to retain enough low-overhead evidence to see which processes were using CPU and memory when load rose. The first phase was intentionally limited to operating-system process sampling. It does not trace every web request, database query, or background job.

You completed the manual package transfer and checksum step. We verified the supplied bundle and its local checks, then installed and enabled the bounded process collector. The bundle checksum matched, and its local test run passed nine tests. The larger manual setup helper was **not** run; the resulting installation contains the process-tracking service described below, rather than the whole proposed tracking stack.

## What is on the VPS

### ENKE process collector

The collector and its systemd units are:

| Purpose | VPS path |
|---|---|
| Collector | `/usr/local/lib/enke-tracking/collect.py` |
| Service | `/etc/systemd/system/enke-tracking-processes.service` |
| Timer | `/etc/systemd/system/enke-tracking-processes.timer` |
| Daily log files | `/var/log/enke-tracking/processes-YYYY-MM-DD.jsonl` |

The collector runs once a minute, at approximately **:20 seconds** past the minute. Each run reads `/proc` twice, about one second apart, to estimate process CPU use. It records the sample timestamp in UTC, CPU count, number of processes seen, load averages, available memory and swap, and process CPU/RSS information. It also aggregates CPU use by process name, such as `php-fpm8.3` and `mysqld`.

The scan is bounded to 4,096 processes. Each log entry retains at most the top 15 processes by CPU and top 10 by RSS (overlap is deduplicated), plus a bounded list of process-name CPU groups. This makes the data useful for identifying the main resource consumers without writing an unlimited process inventory every minute. A process that starts and exits between the two scans can be missed. Per-process RSS includes shared pages, so the RSS values must not be added together as if they were separate physical memory.

The collector records process names and numeric PIDs; it does not record command-line arguments, environment variables, HTTP headers, tenant tokens, request bodies or SQL statements.

### Resource and privilege limits

The systemd service runs at low priority and with narrow resource limits:

- `Nice=19` and idle I/O scheduling priority.
- CPU quota of **2% of one CPU** and memory limit of **64 MiB**.
- Maximum of 12 tasks and an 8-second run timeout.
- `NoNewPrivileges`, a read-only system view, protected home directories, an empty capability set, and Unix-socket-only address families.

The limits are part of the installed service unit. CPU and memory accounting were also enabled as systemd runtime properties so we could inspect the collector's own use. Those accounting toggles are runtime state and may need to be re-enabled after a future reboot; they are separate from the service's CPU and memory limits.

The log directory and daily files are root-owned and mode `0600`. Retention is bounded to 8 MiB per daily file and 14 days. The collector has used about **0.11–0.12 CPU seconds per successful run** in the measured samples—roughly **0.05% of total four-core VPS capacity averaged over a minute**. Its measured peak RSS was about 13 MiB, under the 64 MiB limit.

### Existing telemetry we inspected

**Sysstat (`sar`)** was already collecting CPU, memory and load summaries every ten minutes, with seven days of history. We used those existing records for longer-term averages. We did not change its cadence, retention or configuration.

**Caddy access logging** was already configured for `erp.cloudposai.in`, writing JSON to `/var/log/caddy/erp-access.log`, rotating at 50 MiB and retaining five rolled files. This is not a VPS-wide access log. We inspected it but did not change the active Caddy configuration or restart Caddy. The extra Caddy logging extension discussed during planning remains pending.

**ERP order-payload auditing** was already present in the India and Saudi ERP code and their MySQL databases when we inspected them. Its middleware is attached to selected order and sync routes, not every application on the VPS. It records request/response payloads, result, duration, request ID and some user/tenant metadata. It caps each encoded payload at 32 KiB and redacts fields whose names contain `password`, `token`, `authorization`, `api_key`, `secret`, `card`, `cvv`, `cvc`, `transaction_number`, `iban` or `account_number`; uploaded files are omitted. Other customer information can remain, so these audit tables and logs should be treated as sensitive. We did not add or deploy this application middleware as part of the process-tracking installation.

## What we deliberately left out

- **MySQL query collector:** not installed. The bounded preflight against Performance Schema timed out at its 500 ms safety limit with MySQL error 3024. We stopped there rather than relaxing the limit or repeatedly querying a busy production database.
- **General request-body logging:** not enabled. Existing ERP auditing covers selected order APIs only, and does not give bodies for the PHP slow requests across all sites. Bodies from requests that were never logged cannot be reconstructed later.
- **Queue-job tracing:** not added. The process sampler can show queue-worker processes when they are among the retained processes, but it does not say which job a worker handled or how long that job took.
- **External services and other machines:** this VPS sampler cannot see work performed by Cloudflare Workers or services on a different host.
- **PM2-managed application inventory:** remained unverified. A read-only PM2 listing for the `superadmin` user was rejected by the command approval gate; we did not retry through another route.

We also did not change application code, enable general PHP request-body capture, alter Caddy or sysstat configuration, restart Caddy/MySQL/PHP, or install a database-query collector. A root-owned staging/backup directory was created at `/root/enke-tracking-20261008/` for the uploaded bundle and the original Caddy/sysstat files.

## Verification and observed results

At the first post-pull watch, the VPS had already rebooted: boot time was **5:01:35 PM IST on 8 October**, and the application services started shortly after. We did not initiate that reboot. This means load changes observed after the pull cannot be attributed to the pull alone.

On **8 October, 6:26:58–7:56:58 PM IST**, 90 one-minute process snapshots were available. The average one-minute load was 1.21 on four cores, and sampled available memory ranged from 9.80 to 10.37 GiB. We saw recurring slow PHP requests and pool-busy messages in that window.

On **8 October, 7:32:05 PM–9 October, 10:32:05 AM IST**, 899 of 900 expected process snapshots were present. The process records showed average CPU use of about 14.9% for PHP-FPM and 7.9% for MySQL across the window. Available ten-minute sysstat intervals covered 14 hours 40 minutes and averaged about 24.2% CPU doing work. The ten-minute CPU history did not show sustained CPU saturation; short process bursts and PHP worker exhaustion were more visible in the minute-level tracking and PHP-FPM logs.

During that 15-hour window:

- The one-minute load average peaked at **8.60 at 9:01 AM IST on 9 October**, then fell back over the following minutes.
- Available RAM in process snapshots ranged from **8.92 to 10.32 GiB**; no kernel OOM-kill entry was found.
- PHP-FPM logged **24 slow-request warnings** (requests still running after roughly 10–13 seconds), **36 pool-busy warnings**, and **7 warnings that the shared pool had reached `pm.max_children = 30`**.
- The slow-request warnings pointed to several deployed apps, led by ERP India (9), Saudi ERP (6), CloudPOS India website (4) and CloudPOS.com website (3). The remaining warnings were in Qatar Service CRM and the ZATCA Laravel API.
- Caddy, MySQL and PHP-FPM reported zero restarts over the inspected window. The disk was 29% used with about 138 GB free at the end of the check.

The missing process snapshot was the **5:30 AM IST** run on 9 October. Systemd terminated that collector run at its 8-second limit. A scheduled Saudi ERP database backup started at the same time; the logs establish that they coincided, not that the backup caused the timeout. The next collector run at 5:31 AM succeeded. No application service was restarted as a result.

At the latest live check on **9 October at about 10:34 AM IST**, the 10-second CPU sample averaged 39.7% doing work, load was about 0.83, and roughly 10.1 GiB of RAM was available. These are historical readings, not a current status report for 15 October.

## How to read the data

- Load average is the number of runnable or uninterruptible tasks averaged over time; compare it with the VPS's four CPU cores.
- Process-group CPU is expressed as a share of total server capacity. For example, 25% means about one fully occupied CPU core on this four-core VPS.
- The process CPU readings are short estimates from two `/proc` scans about one second apart. They can reveal bursts but are not a continuous per-request profile.
- Sysstat produces ten-minute averages, which smooth out short spikes and may have gaps at file rotation or collection boundaries.
- RSS includes shared memory. Use the system-wide available-memory field to assess remaining RAM.
- PHP-FPM's slow log identifies a PHP front-controller process and a stack snapshot, but usually not the original URL or request body. The operating-system collector also has no API, tenant or SQL attribution.

## Operational stop command

To disable future process samples while retaining the existing logs:

```sh
systemctl disable --now enke-tracking-processes.timer
systemctl stop enke-tracking-processes.service
```

This only stops the collector and its timer; it does not stop Caddy, MySQL, PHP-FPM or the applications.
