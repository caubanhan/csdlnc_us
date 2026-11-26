#!/usr/bin/env bash
# Tạo nhãn (label), mốc tuần (milestone T1–T5) và các việc (issue) theo kế hoạch GĐ2.
# Yêu cầu: đã cài GitHub CLI (gh), đã chạy "gh auth login", và đang đứng trong thư mục repo đã push lên GitHub.
# Chạy MỘT lần:  bash scripts/tao_board_github.sh
# Sau đó vào tab Issues gán người làm (Assignees) cho từng việc, và thêm các issue vào board GitHub Projects.
set -euo pipefail

echo "== Tạo nhãn"
for nhan in VD1 VD2 VD3 VD4 VD5; do
  gh label create "$nhan" --color "1d76db" --description "Vấn đề ${nhan#VD} của đề" --force
done
gh label create sql    --color "5319e7" --force
gh label create app    --color "0e8a16" --force
gh label create data   --color "fbca04" --force
gh label create report --color "c5def5" --force
gh label create hoc    --color "d4c5f9" --description "Học kiến thức nền" --force

echo "== Tạo mốc tuần"
for t in T1 T2 T3 T4 T5; do
  gh api "repos/{owner}/{repo}/milestones" -f title="$t" >/dev/null 2>&1 || echo "  (mốc $t đã có)"
done

viec() { # viec <mốc> <nhãn,nhãn> <tiêu đề> <mô tả>
  gh issue create --milestone "$1" --label "$2" --title "$3" --body "$4" >/dev/null
  echo "  + [$1] $3"
}

echo "== Tạo việc"
viec T1 hoc         "[Cả nhóm] Học 8 ý trong mục Kiến thức cần nắm" "Mỗi người trả lời được 8 câu tự kiểm tra trong tài liệu kế hoạch."
viec T1 sql         "[Ngọc] Vá lược đồ GĐ1 và viết sql/01_schema.sql" "Theo checklist mục 'Việc cần vá từ GĐ1'. Thay cho sql/01_schema_tam_nhan.sql."
viec T1 report      "[Anh] Đặc tả KB01–KB04" "Mẫu: docs/dac_ta_KB05_KB06_KB09.md"
viec T1 report      "[Anh] Dựng khung ma trận tham chiếu và mẫu phân tích truy vấn" "Phần của Nhân đã có sẵn dòng ở cuối docs/dac_ta_KB05_KB06_KB09.md"
viec T1 report      "[Ngọc] Đặc tả KB07, KB08, KB10" "Mẫu: docs/dac_ta_KB05_KB06_KB09.md"
viec T1 report,VD2  "[Nhân] Đặc tả KB05, KB06, KB09" "Đã có: docs/dac_ta_KB05_KB06_KB09.md. Rà lại rồi đóng."
viec T1 app         "[Nhân] Khung app Streamlit + kết nối CSDL" "Đã có: app/. Mỗi người chạy thử được trên máy mình thì đóng."
viec T2 data        "[Ngọc] Script sinh dữ liệu toàn bộ (≥ 70.000 dòng các bảng minh họa)" "Có thể tái dùng sql/datagen/du_lieu_thu_nhan.sql cho các bảng PT."
viec T2 report      "[Anh] Điền ma trận tham chiếu cho 10 KB + nhận xét" ""
viec T2 sql,VD1,VD4 "[Anh] Đo TRƯỚC KB01–KB04" "Theo mục 'Cách đo' của kế hoạch."
viec T2 sql,VD3,VD5 "[Ngọc] Đo TRƯỚC KB07, KB08, KB10" "Theo mục 'Cách đo' của kế hoạch."
viec T2 sql,VD2,VD5 "[Nhân] Đo TRƯỚC KB05, KB06, KB09" "sql/benchmarks/KB05_a, KB05_b/c (phần TRƯỚC), KB06 phần 1, KB09 phần 1–2a."
viec T3 sql,VD1     "[Anh] Giải pháp vấn đề 1: index cổng vào, sp_CheckIn, đo SAU" ""
viec T3 sql,VD4     "[Anh] Giải pháp vấn đề 4: cộng dồn điểm/hạng khi thanh toán, đo SAU" ""
viec T3 sql,VD3     "[Ngọc] Giải pháp vấn đề 3: partition NHAT_KY_CHECKIN, bảng tổng hợp, đo SAU" ""
viec T3 sql,VD5     "[Ngọc] KB10 đối soát hoa hồng theo tháng, đo SAU" "Dùng TienHoaHongPT đã chốt ở sp_HoanThanhBuoiPT."
viec T3 sql,VD2,VD5 "[Nhân] Đo SAU KB05, KB06, KB09 + chụp hình + nhận xét" "Phần SAU của các file benchmark."
viec T4 app         "[Anh] Trang check-in, tra cứu hội viên, thanh toán" "Thêm file app/pages/4_..., 5_..., 6_..."
viec T4 app         "[Ngọc] Trang báo cáo lấp đầy, doanh thu, hoa hồng" "Thêm file app/pages/7_..., 8_..., 9_..."
viec T4 app         "[Nhân] Ghép app, chạy trọn mạch 10 KB trên một máy" ""
viec T5 report      "[Cả nhóm] Viết phần báo cáo của mình" "Theo mục 'Cấu trúc báo cáo GĐ2'."
viec T5 sql         "[Ngọc] Chạy lại toàn bộ script từ đầu trên CSDL trống" ""
viec T5 report      "[Nhân] Ghép báo cáo, quay video demo dự phòng" ""
echo "Xong."
