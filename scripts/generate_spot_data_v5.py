import cv2
import json
import numpy as np
import os
from pathlib import Path

def generate_clean_json(original_path, modified_path, output_json_path):
    """
    V3 개선 버전:
    - 우측 하단 워터마크 영역 무시
    - 강력한 병합 (Dilation 강화)
    - 중복 박스 제거
    """
    # 1. 이미지 로드
    img1 = cv2.imread(original_path)
    img2 = cv2.imread(modified_path)

    if img1 is None or img2 is None:
        print(f"❌ 오류: 이미지를 찾을 수 없습니다.")
        return False

    # 이미지 크기가 다르면 원본 크기에 맞춰 리사이즈
    h1, w1 = img1.shape[:2]
    h2, w2 = img2.shape[:2]
    
    if (w1, h1) != (w2, h2):
        print(f"⚠️  이미지 크기 불일치: 원본({w1}x{h1}) vs 틀린그림({w2}x{h2}), 틀린그림을 원본 크기로 리사이즈합니다.")
        img2 = cv2.resize(img2, (w1, h1), interpolation=cv2.INTER_LINEAR)
    
    height, width = img1.shape[:2]
    
    # 2. LAB 색상 공간 변환
    lab1 = cv2.cvtColor(img1, cv2.COLOR_BGR2LAB)
    lab2 = cv2.cvtColor(img2, cv2.COLOR_BGR2LAB)

    # 3. 차이 계산 (색상 가중치)
    diff_l = cv2.absdiff(lab1[:,:,0], lab2[:,:,0])
    diff_a = cv2.absdiff(lab1[:,:,1], lab2[:,:,1])
    diff_b = cv2.absdiff(lab1[:,:,2], lab2[:,:,2])
    
    diff = cv2.addWeighted(diff_l, 0.5, diff_a, 2.0, 0)
    diff = cv2.addWeighted(diff, 1.0, diff_b, 2.0, 0)

    # ==========================================================
    # 🛠️ [수정 1] 우측 하단 워터마크 영역 강제 삭제 (Masking)
    # ==========================================================
    # 화면의 오른쪽 15%, 아래쪽 15% 영역을 검은색으로 칠해버립니다.
    mask_w = int(width * 0.15) 
    mask_h = int(height * 0.15)
    # 우측 하단 좌표: (전체너비 - 15% ~ 전체너비, 전체높이 - 15% ~ 전체높이)
    cv2.rectangle(diff, (width - mask_w, height - mask_h), (width, height), 0, -1)

    # 4. 이진화
    _, thresh = cv2.threshold(diff, 30, 255, cv2.THRESH_BINARY)

    # ==========================================================
    # 🛠️ [수정 2] 자잘한 패턴 뭉치기 (커널 크기 및 반복 증가)
    # ==========================================================
    # kernel 크기를 (5,5) -> (15,15)로 키워서 멀리 떨어진 점들도 하나로 뭉칩니다.
    # 이불의 땡땡이 무늬처럼 흩어진 것들을 한 덩어리로 만듭니다.
    kernel = np.ones((15, 15), np.uint8) 
    
    # 노이즈 제거
    opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)
    # 뭉치기 (iterations를 늘리면 더 크게 뭉쳐집니다)
    dilated = cv2.dilate(opening, kernel, iterations=4) 
    
    # 5. 윤곽선 찾기
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    spots = []
    
    # 임시 저장소 (박스 중복 제거용)
    raw_rects = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        if w < 20 or h < 20: continue # 너무 작은 점 무시
        if w > width * 0.95: continue # 화면 전체 에러 무시
        raw_rects.append((x, y, w, h))

    # ==========================================================
    # 🛠️ [수정 3] 중복/포함된 박스 정리
    # ==========================================================
    # 어떤 박스가 다른 박스 안에 완전히 포함되면 제거합니다.
    final_rects = []
    for i, (x1, y1, w1, h1) in enumerate(raw_rects):
        is_contained = False
        for j, (x2, y2, w2, h2) in enumerate(raw_rects):
            if i == j: continue
            # 박스 i가 박스 j 안에 포함되는지 확인
            if x2 <= x1 and y2 <= y1 and (x2+w2) >= (x1+w1) and (y2+h2) >= (y1+h1):
                is_contained = True
                break
        if not is_contained:
            final_rects.append((x1, y1, w1, h1))

    # 6. JSON 생성
    spot_id = 1
    debug_img = img2.copy()
    
    # 워터마크 무시 영역 표시 (파란색 빗금 박스 - 디버그용)
    cv2.rectangle(debug_img, (width - mask_w, height - mask_h), (width, height), (255, 0, 0), 2)
    cv2.line(debug_img, (width - mask_w, height - mask_h), (width, height), (255, 0, 0), 2)

    for (x, y, w, h) in final_rects:
        center_x = x + w / 2
        center_y = y + h / 2
        
        spot_data = {
            "id": spot_id,
            "x": int(x),
            "y": int(y),
            "width": int(w),
            "height": int(h),
            "center_x": int(center_x),
            "center_y": int(center_y),
            "relative_x": round(center_x / width, 4),
            "relative_y": round(center_y / height, 4),
            "relative_radius": round(max(w, h) / 2 / width, 4)
        }
        spots.append(spot_data)
        
        # 초록색 박스 그리기
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 255, 0), 3)
        cv2.putText(debug_img, str(spot_id), (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        
        spot_id += 1

    # 7. 저장
    with open(output_json_path, 'w', encoding='utf-8') as f:
        json.dump(spots, f, indent=2)

    debug_filename = output_json_path.replace('.json', '_debug.jpg')
    cv2.imwrite(debug_filename, debug_img)

    print(f"✅ [{output_json_path}] 생성 완료! (찾은 개수: {len(spots)}개)")
    print(f"   👉 우측 하단 워터마크 무시됨")
    print(f"   👉 자잘한 패턴 뭉치기 적용됨")
    return True


def process_all_stages():
    """
    모든 스테이지에 대해 JSON 생성
    """
    # 경로 설정
    base_dir = Path(__file__).parent.parent
    image_dir = base_dir / "assets" / "soptTheDifference"
    output_dir = base_dir / "assets" / "spot_results_v5"
    
    # 출력 디렉토리 생성
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 레벨별 스테이지 개수
    stage_count_by_level = {
        1: 7,  # 1-1 ~ 1-7
        2: 6,  # 2-1 ~ 2-6
        3: 6,  # 3-1 ~ 3-6
        4: 6,  # 4-1 ~ 4-6
        5: 7,  # 5-1 ~ 5-7
    }
    
    success_count = 0
    fail_count = 0
    
    print("=" * 60)
    print("🚀 spot_results_v5 JSON 생성 시작 (V3 개선 버전)")
    print("   - 우측 하단 워터마크 무시")
    print("   - 강력한 병합 (Dilation 강화)")
    print("   - 중복 박스 제거")
    print("=" * 60)
    
    for level in range(1, 6):
        stage_count = stage_count_by_level[level]
        for stage in range(1, stage_count + 1):
            stage_key = f"{level}-{stage}"
            
            original_path = image_dir / f"{stage_key}.png"
            modified_path = image_dir / f"{stage_key}-wrong.png"
            output_path = output_dir / f"{stage_key}.json"
            
            if not original_path.exists():
                print(f"⚠️  [{stage_key}] 원본 이미지 없음: {original_path}")
                fail_count += 1
                continue
                
            if not modified_path.exists():
                print(f"⚠️  [{stage_key}] 틀린그림 이미지 없음: {modified_path}")
                fail_count += 1
                continue
            
            print(f"\n📝 처리 중: {stage_key}...")
            if generate_clean_json(str(original_path), str(modified_path), str(output_path)):
                success_count += 1
            else:
                fail_count += 1
    
    print("\n" + "=" * 60)
    print(f"✅ 완료! 성공: {success_count}개, 실패: {fail_count}개")
    print(f"📁 출력 폴더: {output_dir}")
    print("=" * 60)


if __name__ == "__main__":
    process_all_stages()

