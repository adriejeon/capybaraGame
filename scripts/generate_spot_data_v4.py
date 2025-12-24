import cv2
import json
import numpy as np
import os
from pathlib import Path

def generate_final_json(original_path, modified_path, output_json_path):
    """
    히트박스를 타이트하게 잡고 색깔 차이를 정확히 잡는 최종 스크립트
    """
    # 1. 이미지 로드
    img1 = cv2.imread(original_path)
    img2 = cv2.imread(modified_path)

    if img1 is None or img2 is None:
        print(f"❌ 오류: 이미지를 찾을 수 없습니다. 경로를 확인하세요: {original_path}, {modified_path}")
        return False

    # 이미지 크기가 다르면 원본 크기에 맞춰 리사이즈
    h1, w1 = img1.shape[:2]
    h2, w2 = img2.shape[:2]
    
    if (w1, h1) != (w2, h2):
        print(f"⚠️  이미지 크기 불일치: 원본({w1}x{h1}) vs 틀린그림({w2}x{h2}), 틀린그림을 원본 크기로 리사이즈합니다.")
        img2 = cv2.resize(img2, (w1, h1), interpolation=cv2.INTER_LINEAR)
    
    height, width = img1.shape[:2]
    
    # 2. LAB 색상 공간 변환 (색깔 차이 감지력 UP)
    lab1 = cv2.cvtColor(img1, cv2.COLOR_BGR2LAB)
    lab2 = cv2.cvtColor(img2, cv2.COLOR_BGR2LAB)

    # 3. 채널별 차이 계산 (색상 채널에 가중치 부여)
    diff_l = cv2.absdiff(lab1[:,:,0], lab2[:,:,0])
    diff_a = cv2.absdiff(lab1[:,:,1], lab2[:,:,1])
    diff_b = cv2.absdiff(lab1[:,:,2], lab2[:,:,2])
    
    # 밝기(L)보다 색상(A, B) 차이에 2배 가중치를 줘서 미세한 색 변화도 잡음
    diff = cv2.addWeighted(diff_l, 0.5, diff_a, 2.0, 0)
    diff = cv2.addWeighted(diff, 1.0, diff_b, 2.0, 0)

    # 4. 이진화 (차이가 25 이상인 것만 추출)
    _, thresh = cv2.threshold(diff, 25, 255, cv2.THRESH_BINARY)

    # 5. 노이즈 제거 및 덩어리 합치기 (히트박스 정리)
    kernel = np.ones((5, 5), np.uint8)
    # 자잘한 점 제거
    opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=1)
    # 가까운 덩어리끼리 합치기 (이 숫자를 늘리면 박스가 더 뭉쳐짐)
    dilated = cv2.dilate(opening, kernel, iterations=3) 
    
    # 6. 윤곽선(박스) 찾기
    contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    spots = []
    spot_id = 1
    
    # 디버깅용 이미지 (초록 박스 그려질 곳)
    debug_img = img2.copy()

    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        
        # [필터] 너무 작거나(15px 미만), 화면을 꽉 채우는(90% 이상) 오류 박스 제외
        if w < 15 or h < 15: 
            continue
        if w > width * 0.9: 
            continue

        # 7. JSON 데이터 생성 (비율 좌표 포함)
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
            "relative_x": round(center_x / width, 4),  # 앱에서 사용하는 핵심 좌표
            "relative_y": round(center_y / height, 4),
            "relative_radius": round(max(w, h) / 2 / width, 4) # 기존 호환성용
        }
        spots.append(spot_data)
        
        # 디버깅 이미지에 박스 그리기
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 255, 0), 2)
        cv2.putText(debug_img, str(spot_id), (x, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        
        spot_id += 1

    # 8. 파일 저장
    # JSON 저장
    with open(output_json_path, 'w', encoding='utf-8') as f:
        json.dump(spots, f, indent=2)

    # 디버그 이미지 저장 (눈으로 꼭 확인하세요!)
    debug_filename = output_json_path.replace('.json', '_debug.jpg')
    cv2.imwrite(debug_filename, debug_img)

    print(f"✅ [{output_json_path}] 생성 완료! (찾은 개수: {len(spots)}개)")
    print(f"   👉 확인용 이미지: {debug_filename}")
    return True


def process_all_stages():
    """
    모든 스테이지에 대해 JSON 생성
    """
    # 경로 설정
    base_dir = Path(__file__).parent.parent
    image_dir = base_dir / "assets" / "soptTheDifference"
    output_dir = base_dir / "assets" / "spot_results_v4"
    
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
    print("🚀 spot_results_v4 JSON 생성 시작")
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
            if generate_final_json(str(original_path), str(modified_path), str(output_path)):
                success_count += 1
            else:
                fail_count += 1
    
    print("\n" + "=" * 60)
    print(f"✅ 완료! 성공: {success_count}개, 실패: {fail_count}개")
    print(f"📁 출력 폴더: {output_dir}")
    print("=" * 60)


if __name__ == "__main__":
    process_all_stages()

