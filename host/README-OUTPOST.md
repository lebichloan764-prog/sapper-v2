# OUTPOST — quy trình chạy legion săn tiền on-chain

Bản fork `lebichloan764-prog/sapper-v2`, chạy trong WSL, không Docker, không đụng
Tencent. Arena là server nội bộ `127.0.0.1:8899`, danh sách mục tiêu trong
`host/targets.json`. Mỗi "flag" nộp vào là một dòng **PROOF**.

## Vai

| vai | não | làm gì |
|---|---|---|
| commander | SMART `glm-5.3-flash[1m]` | đọc board, chia việc, không tự chạy lệnh |
| general | SMART | tự lên cả chuỗi, được thuê squad |
| soldier | LINE `deepseek-v4.1-flash-uncensored[1m]` | đo, replay fork, nộp proof |
| scout | LINE | 4 phút khảo sát, không đánh |
| watchdog | script thuần | dựng lại pane chết, xoay key, hết giờ thì đóng |

## Cổng chặn (không được phá)

1. Không có số thì không tính là kết quả.
2. Fork PASS (tx hash + delta ví mình > 0) → đo gas → mới đề xuất bắn mainnet.
3. Không GraphQL trong quyết định bắn; đọc `position()` + đúng oracle của market.
4. Một lần đọc giá mỗi head, một tx mỗi head.
5. Đóng mục tiêu khi còn proof chưa nộp = mất proof.

## Lệnh

Outpost chạy như service systemd trong WSL và tự dựng lại sau restart:
`/etc/wsl.conf` có `[boot] command=` (chạy mỗi lần WSL khởi động) và
`%APPDATA%\...\Startup\outpost-up.cmd` giữ một nhịp 30 giây để WSL không tự tắt
khi máy rảnh (WSL mặc định tắt distro sau ~60 giây không hoạt động — tắt distro
là mất mọi pane đang chạy). `.wslconfig` cũng đã nâng `vmIdleTimeout`.

```bash
wsl
systemctl status sapper-outpost          # đang chạy?
systemctl restart sapper-outpost         # dựng lại sạch (giữ đồ thị + state)
systemctl stop sapper-outpost            # dừng, giữ nguyên đồ thị

cd ~/sapper/repo/host && . ./env.sh
bash board.sh                            # board chiến dịch
bash board.sh ledger                     # điểm + state + log
tmux attach -t sapper-cmd                # xem trực tiếp (Ctrl-b d để thoát)
bash boot.sh --reset                     # dựng lại bằng tay (480 phút)
bash stop.sh                             # dừng bằng tay
```

Thêm mục tiêu: sửa `targets.json` (code, coordinates trong `addr[]`, `note`),
rồi `systemctl restart sapper-outpost`.

## Trình tự một mục tiêu

```
scout -p 4'  →  đo khoảng cách bằng oracle thật  →  pin fork + replay
→  PASS (tx hash, delta wei)  →  đo gas  →  nộp PROOF  →  đóng, trả slot
```

Sát ngưỡng ≤ 1 %: cho soldier. Cần dựng watcher / calldata mới: cho general.
Protocol lạ: scout góc khác rồi mới general.

## Đọc kết quả

- `bash board.sh` — mã, điểm, số fact, pane đang chạy, đồng hồ ngân sách.
- `~/sapper/runs/<code>/.sapper/graph` — toàn bộ fact đã đo.
- `~/sapper/runs/commander-state.md` — sổ của commander: khoảng cách, gas đo được,
  delta trên fork, thời gian tới lúc bắn.
- `bash board.sh ledger` — bảng điểm arena + 40 dòng state.

Ví dùng chung: `0x8753af58F6fDafD24e800316F3C25CdfeD534bd9`. Chỉ nạp khi có PASS
kèm gas đo được và tỷ lệ/thời gian bắn rõ ràng.

## Ưu tiên hiện tại

1. `firm-e32a` — 0,241 % (689 DOLA) · 2. `firm-80c6` — 0,277 %
3. `morpho-cbxrp` — chênh theo oracle · 4. `aave-cfd2` — 3,14 %, $271k
5. `morpho-usr` — oracle 29× spot · 6. `silo-base` — chỉ trinh sát

## Sự cố

- Pane chết: watchdog tự dựng lại `--continue` (tối đa 3 lần).
- `spawn` exit 3: hết slot, `kill <code> --close` một mục tiêu đã park rồi thử lại.
- `spawn` exit 4: chạm trần pane, giết pane kém nhất.
- RPC 429: đổi endpoint, ghi fact.
- Máy restart: `bash boot.sh` lại; đồ thị và state nằm trên đĩa, chạy tiếp từ đó.
