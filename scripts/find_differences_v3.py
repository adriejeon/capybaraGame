#!/usr/bin/env python3
"""
틀린그림찾기 이미지 분석 스크립트 v3.0
======================================

🎯 핵심 개선: 색상 변화 감지 강화!
- 그레이스케일 변환 없이 RGB 채널별 직접 비교
- 밝기가 비슷해도 색상이 다르면 감지 (주황→초록 등)
- 모든 차이점을 빠짐없이 감지

사용법:
    python3 find_differences_v3.py -o <원본이미지> -d <틀린그림이미지>
    python3 find_differences_v3.py --all <이미지폴더>

필요 라이브러리:
    pip install opencv-python numpy
"""

import cv2
import numpy as np
import json
import argparse
import os
from pathlib import Path
from typing import List, Tuple, Dict, Optional
from dataclasses import dataclass

# ============================================================================
# 🔧 설정 파라미터 (민감하게 설정됨!)
# ============================================================================

@dataclass
class Config:
    """분석 설정 파라미터"""
    # 전처리 설정
    blur_kernel_size: int = 3          # Gaussian Blur 커널 크기 (작게!)
    
    # 차이 감지 설정 (낮은 임계값 = 민감하게)
    color_threshold: int = 15          # RGB 차이 임계값 (낮을수록 민감)
    
    # 노이즈 제거 설정 (작은 커널 = 작은 차이도 보존)
    morph_kernel_size: int = 3         # Morphology 커널 크기 (작게!)
    open_iterations: int = 1           # Opening 반복 횟수
    close_iterations: int = 2          # Closing 반복 횟수
    
    # 컨투어 필터링 설정
    min_contour_area: int = 50         # 최소 컨투어 면적 (작게!)
    
    # 바운딩 박스 병합 설정
    merge_distance: int = 25           # 병합 거리 임계값 (픽셀)
    
    # 출력 설정
    bbox_padding: int = 10             # 바운딩 박스 여유 공간 (픽셀)


# 기본 설정 인스턴스 (민감하게!)
DEFAULT_CONFIG = Config()

# 민감도 프리셋
SENSITIVITY_PRESETS = {
    'normal': Config(
        color_threshold=20,
        min_contour_area=80,
        morph_kernel_size=5,
        open_iterations=2,
        close_iterations=2
    ),
    'sensitive': Config(  # 기본값으로 사용
        color_threshold=15,
        min_contour_area=50,
        morph_kernel_size=3,
        open_iterations=1,
        close_iterations=2
    ),
    'very_sensitive': Config(
        color_threshold=10,
        min_contour_area=30,
        morph_kernel_size=3,
        open_iterations=1,
        close_iterations=1
    ),
    'extreme': Config(
        color_threshold=8,
        min_contour_area=20,
        morph_kernel_size=3,
        open_iterations=1,
        close_iterations=1
    )
}


# ============================================================================
# 🔍 이미지 로딩 및 검증
# ============================================================================

def load_images(original_path: str, diff_path: str) -> Tuple[np.ndarray, np.ndarray]:
    """두 이미지를 로드하고 검증합니다."""
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
        print(f"⚠️  이미지 크기가 다릅니다. 원본: {original.shape[:2]}, 틀린그림: {diff.shape[:2]}")
        diff = cv2.resize(diff, (original.shape[1], original.shape[0]), 
                          interpolation=cv2.INTER_AREA)
    
    return original, diff


# ============================================================================
# 🎨 색상 기반 차이 마스크 계산 (핵심 알고리즘!)
# ============================================================================

def compute_color_difference_mask(
    img1: np.ndarray, 
    img2: np.ndarray, 
    config: Config = DEFAULT_CONFIG,
    debug_output_dir: Optional[str] = None
) -> np.ndarray:
    """
    두 이미지의 차이를 RGB 색상 기반으로 계산합니다.
    
    🚫 그레이스케일 변환 없음!
    ✅ RGB 채널별 직접 비교로 색상 변화 감지
    
    Args:
        img1: 첫 번째 이미지 (BGR)
        img2: 두 번째 이미지 (BGR)
        config: 설정 파라미터
        debug_output_dir: 디버그 이미지 저장 디렉토리
    
    Returns:
        이진 마스크 (차이가 있는 부분이 흰색)
    """
    blur_size = (config.blur_kernel_size, config.blur_kernel_size)
    
    # -------------------------------------------------------------------------
    # 1. 노이즈 감소를 위한 가벼운 블러 (컬러 유지!)
    # -------------------------------------------------------------------------
    img1_blur = cv2.GaussianBlur(img1, blur_size, 0)
    img2_blur = cv2.GaussianBlur(img2, blur_size, 0)
    
    # -------------------------------------------------------------------------
    # 2. RGB 채널별 절대 차이 계산 (🚫 그레이스케일 변환 없음!)
    # -------------------------------------------------------------------------
    # BGR 순서로 각 채널의 차이를 계산
    diff_bgr = cv2.absdiff(img1_blur, img2_blur)
    
    # 디버그: Raw 차이 이미지 저장
    if debug_output_dir:
        cv2.imwrite(os.path.join(debug_output_dir, "debug_01_raw_diff_color.jpg"), diff_bgr)
    
    # -------------------------------------------------------------------------
    # 3. 채널별 차이를 하나로 합치기 (여러 방법 사용)
    # -------------------------------------------------------------------------
    
    # 방법 1: 각 채널 중 최대값 (어떤 채널이든 변화가 있으면 감지)
    diff_max = np.max(diff_bgr, axis=2).astype(np.uint8)
    
    # 방법 2: 모든 채널의 합 (여러 채널이 동시에 바뀌면 더 강하게)
    diff_sum = np.sum(diff_bgr.astype(np.float32), axis=2)
    diff_sum = np.clip(diff_sum / 3, 0, 255).astype(np.uint8)
    
    # 방법 3: HSV 색상 공간에서 Hue(색조) 차이 (색상 변화에 특화!)
    hsv1 = cv2.cvtColor(img1_blur, cv2.COLOR_BGR2HSV)
    hsv2 = cv2.cvtColor(img2_blur, cv2.COLOR_BGR2HSV)
    
    # Hue는 원형이라서 0과 180이 가까움 (빨간색)
    hue_diff = np.abs(hsv1[:,:,0].astype(np.int16) - hsv2[:,:,0].astype(np.int16))
    hue_diff = np.minimum(hue_diff, 180 - hue_diff).astype(np.uint8)  # 원형 거리
    
    # Saturation 차이도 확인 (색이 빠지거나 진해진 경우)
    sat_diff = cv2.absdiff(hsv1[:,:,1], hsv2[:,:,1])
    
    # Value(밝기) 차이
    val_diff = cv2.absdiff(hsv1[:,:,2], hsv2[:,:,2])
    
    # 디버그 이미지 저장
    if debug_output_dir:
        cv2.imwrite(os.path.join(debug_output_dir, "debug_02_diff_max_channel.jpg"), diff_max)
        cv2.imwrite(os.path.join(debug_output_dir, "debug_03_diff_sum_channels.jpg"), diff_sum)
        cv2.imwrite(os.path.join(debug_output_dir, "debug_04_hue_diff.jpg"), hue_diff * 2)  # 시각화를 위해 2배
        cv2.imwrite(os.path.join(debug_output_dir, "debug_05_saturation_diff.jpg"), sat_diff)
        cv2.imwrite(os.path.join(debug_output_dir, "debug_06_value_diff.jpg"), val_diff)
    
    # -------------------------------------------------------------------------
    # 4. 모든 차이 방법을 통합한 마스크 생성
    # -------------------------------------------------------------------------
    
    # RGB 최대 채널 차이 마스크
    _, mask_rgb = cv2.threshold(diff_max, config.color_threshold, 255, cv2.THRESH_BINARY)
    
    # Hue 차이 마스크 (색조 변화 감지) - 더 민감하게 설정
    hue_threshold = max(5, config.color_threshold // 3)  # Hue는 범위가 0-180이라 더 민감하게
    _, mask_hue = cv2.threshold(hue_diff, hue_threshold, 255, cv2.THRESH_BINARY)
    
    # Saturation이 충분히 높은 영역에서만 Hue 차이 적용 (회색 영역 제외)
    # 둘 중 하나라도 채도가 있으면 색상 비교 의미 있음
    sat_combined = np.maximum(hsv1[:,:,1], hsv2[:,:,1])
    sat_mask = (sat_combined > 30).astype(np.uint8) * 255
    mask_hue = cv2.bitwise_and(mask_hue, sat_mask)
    
    # Saturation 차이 마스크 (색 빠짐/진해짐)
    _, mask_sat = cv2.threshold(sat_diff, config.color_threshold + 10, 255, cv2.THRESH_BINARY)
    
    # Value(밝기) 차이 마스크
    _, mask_val = cv2.threshold(val_diff, config.color_threshold, 255, cv2.THRESH_BINARY)
    
    # 디버그: 각 마스크 저장
    if debug_output_dir:
        cv2.imwrite(os.path.join(debug_output_dir, "debug_07_mask_rgb.jpg"), mask_rgb)
        cv2.imwrite(os.path.join(debug_output_dir, "debug_08_mask_hue.jpg"), mask_hue)
        cv2.imwrite(os.path.join(debug_output_dir, "debug_09_mask_saturation.jpg"), mask_sat)
        cv2.imwrite(os.path.join(debug_output_dir, "debug_10_mask_value.jpg"), mask_val)
    
    # -------------------------------------------------------------------------
    # 5. 모든 마스크 통합 (OR 연산)
    # -------------------------------------------------------------------------
    combined_mask = mask_rgb.copy()
    combined_mask = cv2.bitwise_or(combined_mask, mask_hue)
    combined_mask = cv2.bitwise_or(combined_mask, mask_sat)
    combined_mask = cv2.bitwise_or(combined_mask, mask_val)
    
    if debug_output_dir:
        cv2.imwrite(os.path.join(debug_output_dir, "debug_11_combined_before_morph.jpg"), combined_mask)
    
    # -------------------------------------------------------------------------
    # 6. Morphological 연산 (작은 커널로 디테일 보존!)
    # -------------------------------------------------------------------------
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, 
        (config.morph_kernel_size, config.morph_kernel_size)
    )
    
    # Opening: 작은 노이즈 점 제거 (가볍게!)
    cleaned_mask = cv2.morphologyEx(
        combined_mask, cv2.MORPH_OPEN, kernel, 
        iterations=config.open_iterations
    )
    
    # Closing: 작은 구멍 메우기
    cleaned_mask = cv2.morphologyEx(
        cleaned_mask, cv2.MORPH_CLOSE, kernel, 
        iterations=config.close_iterations
    )
    
    if debug_output_dir:
        cv2.imwrite(os.path.join(debug_output_dir, "debug_12_final_mask.jpg"), cleaned_mask)
    
    return cleaned_mask


# ============================================================================
# 📦 컨투어 검출 및 필터링
# ============================================================================

def find_and_filter_contours(
    binary_mask: np.ndarray, 
    min_area: int = 50
) -> List[np.ndarray]:
    """이진 마스크에서 컨투어를 찾고 면적으로 필터링합니다."""
    contours, _ = cv2.findContours(
        binary_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )
    
    # 최소 면적 이상의 컨투어만 선택
    filtered = [cnt for cnt in contours if cv2.contourArea(cnt) >= min_area]
    
    return filtered


def get_bounding_boxes(contours: List[np.ndarray]) -> List[Tuple[int, int, int, int]]:
    """컨투어에서 바운딩 박스를 추출합니다."""
    return [cv2.boundingRect(cnt) for cnt in contours]


# ============================================================================
# 🔗 바운딩 박스 병합 (Union-Find 알고리즘)
# ============================================================================

class UnionFind:
    """Union-Find (Disjoint Set) 자료구조"""
    def __init__(self, n: int):
        self.parent = list(range(n))
        self.rank = [0] * n
    
    def find(self, x: int) -> int:
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent[x]
    
    def union(self, x: int, y: int) -> None:
        px, py = self.find(x), self.find(y)
        if px == py:
            return
        if self.rank[px] < self.rank[py]:
            px, py = py, px
        self.parent[py] = px
        if self.rank[px] == self.rank[py]:
            self.rank[px] += 1


def boxes_are_close(
    box1: Tuple[int, int, int, int], 
    box2: Tuple[int, int, int, int], 
    distance: int
) -> bool:
    """두 바운딩 박스가 지정된 거리 이내인지 확인합니다."""
    x1, y1, w1, h1 = box1
    x2, y2, w2, h2 = box2
    
    left1, right1 = x1 - distance, x1 + w1 + distance
    top1, bottom1 = y1 - distance, y1 + h1 + distance
    
    left2, right2 = x2, x2 + w2
    top2, bottom2 = y2, y2 + h2
    
    horizontal_overlap = left1 < right2 and right1 > left2
    vertical_overlap = top1 < bottom2 and bottom1 > top2
    
    return horizontal_overlap and vertical_overlap


def merge_bounding_boxes(
    boxes: List[Tuple[int, int, int, int]], 
    merge_distance: int = 25
) -> List[Tuple[int, int, int, int]]:
    """가까운 바운딩 박스들을 병합합니다."""
    if not boxes:
        return []
    
    n = len(boxes)
    uf = UnionFind(n)
    
    for i in range(n):
        for j in range(i + 1, n):
            if boxes_are_close(boxes[i], boxes[j], merge_distance):
                uf.union(i, j)
    
    groups: Dict[int, List[int]] = {}
    for i in range(n):
        root = uf.find(i)
        if root not in groups:
            groups[root] = []
        groups[root].append(i)
    
    merged_boxes = []
    for indices in groups.values():
        min_x = min(boxes[i][0] for i in indices)
        min_y = min(boxes[i][1] for i in indices)
        max_x = max(boxes[i][0] + boxes[i][2] for i in indices)
        max_y = max(boxes[i][1] + boxes[i][3] for i in indices)
        
        merged_boxes.append((min_x, min_y, max_x - min_x, max_y - min_y))
    
    return merged_boxes


def add_padding_to_boxes(
    boxes: List[Tuple[int, int, int, int]], 
    padding: int, 
    img_width: int, 
    img_height: int
) -> List[Tuple[int, int, int, int]]:
    """바운딩 박스에 패딩을 추가합니다."""
    padded = []
    for x, y, w, h in boxes:
        new_x = max(0, x - padding)
        new_y = max(0, y - padding)
        new_right = min(img_width, x + w + padding)
        new_bottom = min(img_height, y + h + padding)
        padded.append((new_x, new_y, new_right - new_x, new_bottom - new_y))
    return padded


# ============================================================================
# 📄 출력 생성
# ============================================================================

def boxes_to_json(
    boxes: List[Tuple[int, int, int, int]], 
    img_width: int, 
    img_height: int
) -> List[Dict]:
    """바운딩 박스를 JSON 형식으로 변환합니다."""
    result = []
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        center_x = x + w // 2
        center_y = y + h // 2
        
        relative_x = round(center_x / img_width, 4)
        relative_y = round(center_y / img_height, 4)
        relative_radius = round(max(w, h) / img_width / 2 * 1.2, 4)
        
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


def draw_debug_image(
    original: np.ndarray, 
    boxes: List[Tuple[int, int, int, int]],
    output_path: str
) -> None:
    """디버그용 이미지를 생성하고 저장합니다."""
    debug_img = original.copy()
    
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        # 빨간색 바운딩 박스
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 0, 255), 3)
        
        # 번호 라벨
        label = str(idx)
        (label_w, label_h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.8, 2)
        cv2.rectangle(debug_img, (x, y - label_h - 10), (x + label_w + 10, y), (0, 0, 255), -1)
        cv2.putText(debug_img, label, (x + 5, y - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        
        # 중심점 (녹색)
        center_x = x + w // 2
        center_y = y + h // 2
        cv2.circle(debug_img, (center_x, center_y), 5, (0, 255, 0), -1)
    
    cv2.imwrite(output_path, debug_img)
    print(f"✅ 디버그 이미지 저장: {output_path}")


# ============================================================================
# 🚀 메인 분석 함수
# ============================================================================

def find_differences(
    original_path: str, 
    diff_path: str, 
    output_json_path: Optional[str] = None,
    output_debug_path: Optional[str] = None,
    config: Optional[Config] = None,
    save_debug_steps: bool = True
) -> List[Dict]:
    """
    두 이미지를 비교하여 다른 부분을 찾습니다.
    
    🎯 색상 변화를 포함한 모든 차이점을 감지합니다!
    """
    if config is None:
        config = SENSITIVITY_PRESETS['sensitive']
    
    print(f"\n{'='*60}")
    print(f"🔍 이미지 분석 시작 (v3.0 - 색상 감지 강화)")
    print(f"{'='*60}")
    print(f"   원본: {original_path}")
    print(f"   틀린그림: {diff_path}")
    print(f"\n📊 설정:")
    print(f"   - 색상 임계값: {config.color_threshold}")
    print(f"   - 최소 면적: {config.min_contour_area}")
    print(f"   - Morph 커널: {config.morph_kernel_size}")
    print(f"   - 병합 거리: {config.merge_distance}")
    
    # 1. 이미지 로드
    original, diff = load_images(original_path, diff_path)
    img_height, img_width = original.shape[:2]
    print(f"\n📐 이미지 크기: {img_width} x {img_height}")
    
    # 디버그 출력 디렉토리 설정
    debug_dir = None
    if save_debug_steps and output_debug_path:
        debug_dir = os.path.dirname(output_debug_path)
        if not debug_dir:
            debug_dir = "."
    
    # 2. 색상 기반 차이 마스크 계산
    print(f"\n🎨 색상 기반 차이 분석 중...")
    binary_mask = compute_color_difference_mask(original, diff, config, debug_dir)
    
    # 3. 컨투어 찾기
    contours = find_and_filter_contours(binary_mask, config.min_contour_area)
    print(f"   → 발견된 컨투어: {len(contours)}개")
    
    # 4. 바운딩 박스 추출
    boxes = get_bounding_boxes(contours)
    
    # 5. 가까운 박스 병합
    merged_boxes = merge_bounding_boxes(boxes, config.merge_distance)
    print(f"   → 병합 후 영역: {len(merged_boxes)}개")
    
    # 6. 패딩 추가
    final_boxes = add_padding_to_boxes(merged_boxes, config.bbox_padding, img_width, img_height)
    
    # 7. JSON 형식으로 변환
    result = boxes_to_json(final_boxes, img_width, img_height)
    
    # 8. JSON 파일 저장
    if output_json_path:
        with open(output_json_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f"\n✅ JSON 저장: {output_json_path}")
    
    # 9. 디버그 이미지 저장
    if output_debug_path:
        draw_debug_image(original, final_boxes, output_debug_path)
    
    # 10. 결과 출력
    print(f"\n{'='*60}")
    print(f"📊 분석 결과: {len(result)}개의 차이점 발견")
    print(f"{'='*60}")
    for spot in result:
        print(f"   #{spot['id']}: "
              f"픽셀({spot['x']}, {spot['y']}, {spot['width']}×{spot['height']}) → "
              f"비율({spot['relative_x']:.4f}, {spot['relative_y']:.4f}, r={spot['relative_radius']:.4f})")
    
    return result


# ============================================================================
# 📁 배치 처리
# ============================================================================

def process_all_stages(
    assets_dir: str, 
    output_dir: Optional[str] = None,
    config: Optional[Config] = None
) -> Dict[str, List[Dict]]:
    """모든 스테이지 이미지를 일괄 처리합니다."""
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(assets_dir), "spot_results_v3")
    
    os.makedirs(output_dir, exist_ok=True)
    
    all_results = {}
    
    png_files = sorted([
        f for f in os.listdir(assets_dir) 
        if f.endswith('.png') and '-wrong' not in f
    ])
    
    print(f"\n🎮 발견된 스테이지: {len(png_files)}개")
    
    for filename in png_files:
        stage_name = filename.replace('.png', '')
        original_path = os.path.join(assets_dir, filename)
        diff_path = os.path.join(assets_dir, f"{stage_name}-wrong.png")
        
        if not os.path.exists(diff_path):
            print(f"⚠️  {stage_name}: 틀린그림 파일 없음, 건너뜀")
            continue
        
        output_json = os.path.join(output_dir, f"{stage_name}.json")
        output_debug = os.path.join(output_dir, f"{stage_name}_debug.jpg")
        
        try:
            result = find_differences(
                original_path=original_path,
                diff_path=diff_path,
                output_json_path=output_json,
                output_debug_path=output_debug,
                config=config,
                save_debug_steps=False  # 배치 처리 시 중간 디버그 생략
            )
            all_results[stage_name] = result
        except Exception as e:
            print(f"❌ {stage_name}: 오류 발생 - {e}")
    
    # 전체 결과 저장
    all_results_path = os.path.join(output_dir, "all_spots.json")
    with open(all_results_path, 'w', encoding='utf-8') as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)
    print(f"\n✅ 전체 결과 저장: {all_results_path}")
    
    # Dart 코드 생성
    dart_code = generate_dart_code(all_results)
    dart_path = os.path.join(output_dir, "spot_data.dart")
    with open(dart_path, 'w', encoding='utf-8') as f:
        f.write(dart_code)
    print(f"✅ Dart 코드 저장: {dart_path}")
    
    return all_results


def generate_dart_code(results: Dict[str, List[Dict]]) -> str:
    """Flutter 앱용 Dart 코드를 생성합니다."""
    lines = [
        "// 자동 생성된 스팟 데이터 (v3.0 - 색상 감지 강화)",
        "// 생성 스크립트: find_differences_v3.py",
        "",
        "static final Map<String, List<DifferenceSpot>> _spotData = {",
    ]
    
    for stage_name in sorted(results.keys()):
        spots = results[stage_name]
        if not spots:
            continue
        
        lines.append(f"  '{stage_name}': [")
        for spot in spots:
            lines.append(
                f"    const DifferenceSpot("
                f"x: {spot['relative_x']}, "
                f"y: {spot['relative_y']}, "
                f"radius: {spot['relative_radius']}),"
            )
        lines.append("  ],")
    
    lines.append("};")
    
    return "\n".join(lines)


# ============================================================================
# 🎯 CLI 진입점
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='틀린그림찾기 이미지 분석 스크립트 v3.0 (색상 감지 강화!)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  # 단일 이미지 분석 (민감하게)
  python3 find_differences_v3.py -o 1-2.png -d 1-2-wrong.png

  # 모든 스테이지 분석
  python3 find_differences_v3.py --all ../assets/soptTheDifference

  # 매우 민감하게 분석
  python3 find_differences_v3.py -o img.png -d img-wrong.png -s very_sensitive

민감도 프리셋:
  normal         - 일반적인 차이 감지
  sensitive      - 민감한 감지 (기본값, 색상 변화 포함)
  very_sensitive - 매우 민감 (미세한 차이도)
  extreme        - 극도로 민감 (모든 픽셀 차이)
        """
    )
    
    parser.add_argument('-o', '--original', type=str, help='원본 이미지 경로')
    parser.add_argument('-d', '--diff', type=str, help='틀린그림 이미지 경로')
    parser.add_argument('-a', '--all', type=str, help='모든 스테이지 처리 (이미지 폴더 경로)')
    
    parser.add_argument('--output', type=str, help='결과 JSON 파일 경로')
    parser.add_argument('--debug', type=str, help='디버그 이미지 경로')
    
    parser.add_argument('-s', '--sensitivity', type=str, default='sensitive',
                        choices=['normal', 'sensitive', 'very_sensitive', 'extreme'],
                        help='민감도 프리셋 (기본: sensitive)')
    parser.add_argument('-t', '--threshold', type=int, default=None,
                        help='색상 차이 임계값 (낮을수록 민감, 기본: 15)')
    parser.add_argument('-m', '--min-area', type=int, default=None,
                        help='최소 컨투어 면적 (기본: 50)')
    parser.add_argument('--merge', type=int, default=None,
                        help='박스 병합 거리 (기본: 25)')
    
    args = parser.parse_args()
    
    # 민감도 프리셋에서 시작
    config = SENSITIVITY_PRESETS.get(args.sensitivity, SENSITIVITY_PRESETS['sensitive'])
    
    # 개별 파라미터로 덮어쓰기
    if args.threshold is not None:
        config = Config(
            blur_kernel_size=config.blur_kernel_size,
            color_threshold=args.threshold,
            morph_kernel_size=config.morph_kernel_size,
            open_iterations=config.open_iterations,
            close_iterations=config.close_iterations,
            min_contour_area=config.min_contour_area,
            merge_distance=config.merge_distance,
            bbox_padding=config.bbox_padding
        )
    if args.min_area is not None:
        config = Config(
            blur_kernel_size=config.blur_kernel_size,
            color_threshold=config.color_threshold,
            morph_kernel_size=config.morph_kernel_size,
            open_iterations=config.open_iterations,
            close_iterations=config.close_iterations,
            min_contour_area=args.min_area,
            merge_distance=config.merge_distance,
            bbox_padding=config.bbox_padding
        )
    if args.merge is not None:
        config = Config(
            blur_kernel_size=config.blur_kernel_size,
            color_threshold=config.color_threshold,
            morph_kernel_size=config.morph_kernel_size,
            open_iterations=config.open_iterations,
            close_iterations=config.close_iterations,
            min_contour_area=config.min_contour_area,
            merge_distance=args.merge,
            bbox_padding=config.bbox_padding
        )
    
    if args.all:
        process_all_stages(args.all, config=config)
    elif args.original and args.diff:
        output_json = args.output or "result.json"
        output_debug = args.debug or "result_debug.jpg"
        
        find_differences(
            original_path=args.original,
            diff_path=args.diff,
            output_json_path=output_json,
            output_debug_path=output_debug,
            config=config,
            save_debug_steps=True
        )
    else:
        parser.print_help()
        print("\n" + "="*60)
        print("💡 빠른 시작 (색상 변화 감지 강화!):")
        print("="*60)
        print("  # 1-2 스테이지 분석 (램프 색상 변화 감지)")
        print("  python3 find_differences_v3.py -o ../assets/soptTheDifference/1-2.png \\")
        print("      -d ../assets/soptTheDifference/1-2-wrong.png")
        print("")
        print("  # 모든 스테이지 분석")
        print("  python3 find_differences_v3.py --all ../assets/soptTheDifference")


if __name__ == "__main__":
    main()

