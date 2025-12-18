#!/usr/bin/env python3
"""
틀린그림찾기 이미지 분석 스크립트
두 이미지를 비교하여 다른 부분의 좌표를 JSON으로 추출합니다.

사용법:
    python find_differences.py --original <원본이미지> --diff <틀린그림이미지> --output <결과JSON>

필요 라이브러리:
    pip install opencv-python numpy
"""

import cv2
import numpy as np
import json
import argparse
import os
from pathlib import Path
from typing import List, Tuple, Dict


def load_and_validate_images(original_path: str, diff_path: str) -> Tuple[np.ndarray, np.ndarray]:
    """이미지를 로드하고 유효성을 검사합니다."""
    if not os.path.exists(original_path):
        raise FileNotFoundError(f"원본 이미지를 찾을 수 없습니다: {original_path}")
    if not os.path.exists(diff_path):
        raise FileNotFoundError(f"틀린그림 이미지를 찾을 수 없습니다: {diff_path}")
    
    original = cv2.imread(original_path)
    diff = cv2.imread(diff_path)
    
    if original is None:
        raise ValueError(f"원본 이미지를 로드할 수 없습니다: {original_path}")
    if diff is None:
        raise ValueError(f"틀린그림 이미지를 로드할 수 없습니다: {diff_path}")
    
    # 이미지 크기가 다르면 리사이즈
    if original.shape != diff.shape:
        print(f"⚠️ 이미지 크기가 다릅니다. 원본: {original.shape}, 틀린그림: {diff.shape}")
        diff = cv2.resize(diff, (original.shape[1], original.shape[0]))
    
    return original, diff


def compute_difference_mask(original: np.ndarray, diff: np.ndarray, 
                            threshold: int = 30, blur_size: int = 5) -> np.ndarray:
    """두 이미지의 차이를 계산하여 이진 마스크를 반환합니다."""
    # 그레이스케일로 변환
    gray_original = cv2.cvtColor(original, cv2.COLOR_BGR2GRAY)
    gray_diff = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
    
    # 노이즈 제거를 위한 블러 적용
    gray_original = cv2.GaussianBlur(gray_original, (blur_size, blur_size), 0)
    gray_diff = cv2.GaussianBlur(gray_diff, (blur_size, blur_size), 0)
    
    # 절대 차이 계산
    diff_image = cv2.absdiff(gray_original, gray_diff)
    
    # 임계값 적용하여 이진 마스크 생성
    _, binary_mask = cv2.threshold(diff_image, threshold, 255, cv2.THRESH_BINARY)
    
    # 모폴로지 연산으로 노이즈 제거 및 영역 확장
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    binary_mask = cv2.morphologyEx(binary_mask, cv2.MORPH_CLOSE, kernel)
    binary_mask = cv2.morphologyEx(binary_mask, cv2.MORPH_OPEN, kernel)
    
    # 영역을 약간 확장 (dilate)
    kernel_dilate = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    binary_mask = cv2.dilate(binary_mask, kernel_dilate, iterations=2)
    
    return binary_mask


def find_difference_contours(binary_mask: np.ndarray, min_area: int = 100) -> List[np.ndarray]:
    """이진 마스크에서 컨투어를 찾아 반환합니다."""
    contours, _ = cv2.findContours(binary_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # 최소 면적 이상의 컨투어만 필터링
    filtered_contours = [cnt for cnt in contours if cv2.contourArea(cnt) >= min_area]
    
    return filtered_contours


def get_bounding_boxes(contours: List[np.ndarray]) -> List[Tuple[int, int, int, int]]:
    """컨투어에서 바운딩 박스를 추출합니다."""
    boxes = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        boxes.append((x, y, w, h))
    return boxes


def merge_overlapping_boxes(boxes: List[Tuple[int, int, int, int]], 
                            overlap_threshold: float = 0.1,
                            distance_threshold: int = 50) -> List[Tuple[int, int, int, int]]:
    """겹치거나 가까운 바운딩 박스들을 병합합니다."""
    if not boxes:
        return []
    
    def boxes_overlap_or_close(box1, box2, dist_thresh):
        """두 박스가 겹치거나 가까운지 확인합니다."""
        x1, y1, w1, h1 = box1
        x2, y2, w2, h2 = box2
        
        # 박스 확장 (distance_threshold만큼)
        x1_ext = x1 - dist_thresh
        y1_ext = y1 - dist_thresh
        w1_ext = w1 + 2 * dist_thresh
        h1_ext = h1 + 2 * dist_thresh
        
        # 확장된 박스1과 박스2가 겹치는지 확인
        if (x1_ext < x2 + w2 and x1_ext + w1_ext > x2 and
            y1_ext < y2 + h2 and y1_ext + h1_ext > y2):
            return True
        return False
    
    def merge_two_boxes(box1, box2):
        """두 박스를 병합합니다."""
        x1, y1, w1, h1 = box1
        x2, y2, w2, h2 = box2
        
        x_min = min(x1, x2)
        y_min = min(y1, y2)
        x_max = max(x1 + w1, x2 + w2)
        y_max = max(y1 + h1, y2 + h2)
        
        return (x_min, y_min, x_max - x_min, y_max - y_min)
    
    # 병합 반복
    merged = list(boxes)
    changed = True
    
    while changed:
        changed = False
        new_merged = []
        used = [False] * len(merged)
        
        for i in range(len(merged)):
            if used[i]:
                continue
            
            current_box = merged[i]
            
            for j in range(i + 1, len(merged)):
                if used[j]:
                    continue
                
                if boxes_overlap_or_close(current_box, merged[j], distance_threshold):
                    current_box = merge_two_boxes(current_box, merged[j])
                    used[j] = True
                    changed = True
            
            new_merged.append(current_box)
            used[i] = True
        
        merged = new_merged
    
    return merged


def add_padding_to_boxes(boxes: List[Tuple[int, int, int, int]], 
                         padding: int, 
                         img_width: int, 
                         img_height: int) -> List[Tuple[int, int, int, int]]:
    """바운딩 박스에 패딩을 추가합니다."""
    padded_boxes = []
    for x, y, w, h in boxes:
        new_x = max(0, x - padding)
        new_y = max(0, y - padding)
        new_w = min(img_width - new_x, w + 2 * padding)
        new_h = min(img_height - new_y, h + 2 * padding)
        padded_boxes.append((new_x, new_y, new_w, new_h))
    return padded_boxes


def boxes_to_json(boxes: List[Tuple[int, int, int, int]], 
                  img_width: int, 
                  img_height: int) -> List[Dict]:
    """바운딩 박스를 JSON 형식으로 변환합니다 (비율 좌표 포함)."""
    result = []
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        # 중심점 계산
        center_x = x + w // 2
        center_y = y + h // 2
        
        # 비율 좌표 계산 (Flutter 앱용)
        relative_x = round(center_x / img_width, 4)
        relative_y = round(center_y / img_height, 4)
        relative_radius = round(max(w, h) / img_width / 2 * 1.2, 4)  # 20% 여유 추가
        
        result.append({
            "id": idx,
            "x": x,
            "y": y,
            "width": w,
            "height": h,
            "center_x": center_x,
            "center_y": center_y,
            "relative_x": relative_x,
            "relative_y": relative_y,
            "relative_radius": relative_radius
        })
    return result


def draw_debug_image(original: np.ndarray, 
                     boxes: List[Tuple[int, int, int, int]],
                     output_path: str) -> None:
    """디버그용 이미지를 생성합니다."""
    debug_img = original.copy()
    
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        # 빨간색 바운딩 박스 그리기
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 0, 255), 3)
        
        # 번호 표시
        cv2.putText(debug_img, str(idx), (x + 5, y + 25), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        
        # 중심점 표시
        center_x = x + w // 2
        center_y = y + h // 2
        cv2.circle(debug_img, (center_x, center_y), 5, (0, 255, 0), -1)
    
    cv2.imwrite(output_path, debug_img)
    print(f"✅ 디버그 이미지 저장: {output_path}")


def find_differences(original_path: str, 
                     diff_path: str, 
                     output_json_path: str = None,
                     output_debug_path: str = None,
                     threshold: int = 30,
                     min_area: int = 100,
                     merge_distance: int = 50,
                     padding: int = 10) -> List[Dict]:
    """
    두 이미지를 비교하여 다른 부분을 찾습니다.
    
    Args:
        original_path: 원본 이미지 경로
        diff_path: 틀린그림 이미지 경로
        output_json_path: 결과 JSON 파일 경로 (선택)
        output_debug_path: 디버그 이미지 경로 (선택)
        threshold: 차이 감지 임계값 (0-255)
        min_area: 최소 영역 크기 (픽셀)
        merge_distance: 박스 병합 거리 (픽셀)
        padding: 바운딩 박스 패딩 (픽셀)
    
    Returns:
        다른 부분의 좌표 정보 리스트
    """
    print(f"\n🔍 이미지 분석 중...")
    print(f"   원본: {original_path}")
    print(f"   틀린그림: {diff_path}")
    
    # 이미지 로드
    original, diff = load_and_validate_images(original_path, diff_path)
    img_height, img_width = original.shape[:2]
    print(f"   이미지 크기: {img_width} x {img_height}")
    
    # 차이 마스크 계산
    binary_mask = compute_difference_mask(original, diff, threshold=threshold)
    
    # 컨투어 찾기
    contours = find_difference_contours(binary_mask, min_area=min_area)
    print(f"   발견된 컨투어: {len(contours)}개")
    
    # 바운딩 박스 추출
    boxes = get_bounding_boxes(contours)
    
    # 겹치는 박스 병합
    merged_boxes = merge_overlapping_boxes(boxes, distance_threshold=merge_distance)
    print(f"   병합 후 영역: {len(merged_boxes)}개")
    
    # 패딩 추가
    final_boxes = add_padding_to_boxes(merged_boxes, padding, img_width, img_height)
    
    # JSON 형식으로 변환
    result = boxes_to_json(final_boxes, img_width, img_height)
    
    # JSON 파일 저장
    if output_json_path:
        with open(output_json_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f"✅ JSON 저장: {output_json_path}")
    
    # 디버그 이미지 저장
    if output_debug_path:
        draw_debug_image(original, final_boxes, output_debug_path)
    
    # 결과 출력
    print(f"\n📊 분석 결과:")
    for spot in result:
        print(f"   스팟 {spot['id']}: 픽셀({spot['x']}, {spot['y']}, {spot['width']}x{spot['height']}) "
              f"→ 비율({spot['relative_x']}, {spot['relative_y']}, r={spot['relative_radius']})")
    
    return result


def generate_flutter_code(results: Dict[str, List[Dict]]) -> str:
    """Flutter 앱용 Dart 코드를 생성합니다."""
    lines = ["// 자동 생성된 스팟 데이터", "static final Map<String, List<DifferenceSpot>> _spotData = {"]
    
    for stage_name, spots in results.items():
        spot_lines = []
        for spot in spots:
            spot_lines.append(
                f"    const DifferenceSpot(x: {spot['relative_x']}, y: {spot['relative_y']}, radius: {spot['relative_radius']})"
            )
        lines.append(f"  '{stage_name}': [")
        lines.append(",\n".join(spot_lines) + ",")
        lines.append("  ],")
    
    lines.append("};")
    return "\n".join(lines)


def process_all_stages(assets_dir: str, output_dir: str = None):
    """모든 스테이지 이미지를 처리합니다."""
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(assets_dir), "spot_results")
    
    os.makedirs(output_dir, exist_ok=True)
    
    all_results = {}
    
    # PNG 파일 찾기
    for filename in sorted(os.listdir(assets_dir)):
        if filename.endswith('.png') and '-wrong' not in filename:
            stage_name = filename.replace('.png', '')
            original_path = os.path.join(assets_dir, filename)
            diff_path = os.path.join(assets_dir, f"{stage_name}-wrong.png")
            
            if os.path.exists(diff_path):
                print(f"\n{'='*50}")
                print(f"📁 스테이지: {stage_name}")
                print(f"{'='*50}")
                
                output_json = os.path.join(output_dir, f"{stage_name}.json")
                output_debug = os.path.join(output_dir, f"{stage_name}_debug.jpg")
                
                try:
                    result = find_differences(
                        original_path=original_path,
                        diff_path=diff_path,
                        output_json_path=output_json,
                        output_debug_path=output_debug,
                        threshold=25,
                        min_area=100,
                        merge_distance=40,
                        padding=15
                    )
                    all_results[stage_name] = result
                except Exception as e:
                    print(f"❌ 오류 발생: {e}")
    
    # 전체 결과 JSON 저장
    all_results_path = os.path.join(output_dir, "all_spots.json")
    with open(all_results_path, 'w', encoding='utf-8') as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)
    print(f"\n✅ 전체 결과 저장: {all_results_path}")
    
    # Flutter 코드 생성
    flutter_code = generate_flutter_code(all_results)
    flutter_code_path = os.path.join(output_dir, "spot_data.dart")
    with open(flutter_code_path, 'w', encoding='utf-8') as f:
        f.write(flutter_code)
    print(f"✅ Flutter 코드 저장: {flutter_code_path}")
    
    return all_results


def main():
    parser = argparse.ArgumentParser(description='틀린그림찾기 이미지 분석 스크립트')
    parser.add_argument('--original', '-o', type=str, help='원본 이미지 경로')
    parser.add_argument('--diff', '-d', type=str, help='틀린그림 이미지 경로')
    parser.add_argument('--output', '-out', type=str, help='결과 JSON 파일 경로')
    parser.add_argument('--debug', type=str, help='디버그 이미지 경로')
    parser.add_argument('--all', '-a', type=str, help='모든 스테이지 처리 (이미지 폴더 경로)')
    parser.add_argument('--threshold', '-t', type=int, default=25, help='차이 감지 임계값 (기본: 25)')
    parser.add_argument('--min-area', '-m', type=int, default=100, help='최소 영역 크기 (기본: 100)')
    parser.add_argument('--merge-dist', type=int, default=40, help='박스 병합 거리 (기본: 40)')
    
    args = parser.parse_args()
    
    if args.all:
        # 모든 스테이지 처리
        process_all_stages(args.all)
    elif args.original and args.diff:
        # 단일 이미지 쌍 처리
        output_json = args.output or "result.json"
        output_debug = args.debug or "result_debug.jpg"
        
        find_differences(
            original_path=args.original,
            diff_path=args.diff,
            output_json_path=output_json,
            output_debug_path=output_debug,
            threshold=args.threshold,
            min_area=args.min_area,
            merge_distance=args.merge_dist
        )
    else:
        print("사용법:")
        print("  단일 이미지: python find_differences.py -o original.png -d diff.png")
        print("  모든 스테이지: python find_differences.py --all /path/to/assets/soptTheDifference")
        print("\n예시:")
        print("  python find_differences.py --all ../assets/soptTheDifference")


if __name__ == "__main__":
    main()
