#!/usr/bin/env python3
"""
틀린그림찾기 이미지 분석 스크립트 v2.0
======================================

두 이미지를 비교하여 다른 부분의 좌표를 JSON으로 추출합니다.

주요 개선사항:
- 다중 색상 공간 분석 (Grayscale + LAB) → 색상 차이 감지 향상
- Union-Find 기반 바운딩 박스 병합 → 효율적인 그룹핑
- 최적화된 노이즈 제거 → False Positive 감소

사용법:
    python find_differences_v2.py --original <원본이미지> --diff <틀린그림이미지>
    python find_differences_v2.py --all <이미지폴더>

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
# 🔧 설정 파라미터 (여기서 조정하세요!)
# ============================================================================

@dataclass
class Config:
    """분석 설정 파라미터"""
    # 전처리 설정
    blur_kernel_size: int = 5          # Gaussian Blur 커널 크기 (홀수)
    
    # 차이 감지 설정
    gray_threshold: int = 30           # 그레이스케일 차이 임계값 (0-255)
    color_threshold: int = 25          # 색상(LAB) 차이 임계값 (0-255)
    
    # 노이즈 제거 설정
    morph_kernel_size: int = 5         # Morphology 커널 크기
    open_iterations: int = 2           # Opening 반복 횟수 (노이즈 제거)
    close_iterations: int = 3          # Closing 반복 횟수 (구멍 메우기)
    
    # 컨투어 필터링 설정
    min_contour_area: int = 150        # 최소 컨투어 면적 (픽셀)
    
    # 바운딩 박스 병합 설정
    merge_distance: int = 30           # 병합 거리 임계값 (픽셀)
    
    # 출력 설정
    bbox_padding: int = 10             # 바운딩 박스 여유 공간 (픽셀)


# 기본 설정 인스턴스
DEFAULT_CONFIG = Config()

# 민감도 프리셋
SENSITIVITY_PRESETS = {
    'low': Config(
        gray_threshold=45,
        color_threshold=40,
        min_contour_area=300,
        merge_distance=35,
        open_iterations=3,
        close_iterations=2
    ),
    'medium': Config(  # 기본값
        gray_threshold=30,
        color_threshold=25,
        min_contour_area=150,
        merge_distance=30,
        open_iterations=2,
        close_iterations=3
    ),
    'high': Config(
        gray_threshold=20,
        color_threshold=18,
        min_contour_area=100,
        merge_distance=25,
        open_iterations=1,
        close_iterations=3
    ),
    'very_high': Config(
        gray_threshold=15,
        color_threshold=12,
        min_contour_area=80,
        merge_distance=20,
        open_iterations=1,
        close_iterations=2
    )
}


# ============================================================================
# 🔍 이미지 로딩 및 검증
# ============================================================================

def load_images(original_path: str, diff_path: str) -> Tuple[np.ndarray, np.ndarray]:
    """
    두 이미지를 로드하고 검증합니다.
    
    Args:
        original_path: 원본 이미지 경로
        diff_path: 틀린그림 이미지 경로
    
    Returns:
        (원본 이미지, 틀린그림 이미지) 튜플
    
    Raises:
        FileNotFoundError: 파일이 없을 때
        ValueError: 이미지 로드 실패 시
    """
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
        print(f"    틀린그림을 원본 크기로 리사이즈합니다.")
        diff = cv2.resize(diff, (original.shape[1], original.shape[0]), 
                          interpolation=cv2.INTER_AREA)
    
    return original, diff


# ============================================================================
# 🎨 차이 마스크 계산 (핵심 알고리즘)
# ============================================================================

def compute_difference_mask(
    img1: np.ndarray, 
    img2: np.ndarray, 
    config: Config = DEFAULT_CONFIG
) -> np.ndarray:
    """
    두 이미지의 차이를 계산하여 이진 마스크를 반환합니다.
    
    그레이스케일과 LAB 색상 공간을 모두 분석하여
    밝기 차이와 색상 차이를 모두 감지합니다.
    
    Args:
        img1: 첫 번째 이미지 (BGR)
        img2: 두 번째 이미지 (BGR)
        config: 설정 파라미터
    
    Returns:
        이진 마스크 (차이가 있는 부분이 흰색)
    """
    blur_size = (config.blur_kernel_size, config.blur_kernel_size)
    
    # -------------------------------------------------------------------------
    # 1. 그레이스케일 차이 계산 (밝기 변화 감지)
    # -------------------------------------------------------------------------
    gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
    gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)
    
    # Gaussian Blur로 노이즈 감소
    gray1_blur = cv2.GaussianBlur(gray1, blur_size, 0)
    gray2_blur = cv2.GaussianBlur(gray2, blur_size, 0)
    
    # 절대 차이 계산
    gray_diff = cv2.absdiff(gray1_blur, gray2_blur)
    
    # 임계값 적용
    _, gray_mask = cv2.threshold(
        gray_diff, config.gray_threshold, 255, cv2.THRESH_BINARY
    )
    
    # -------------------------------------------------------------------------
    # 2. LAB 색상 공간 차이 계산 (색상 변화 감지)
    # -------------------------------------------------------------------------
    # LAB 색상 공간은 인간의 색상 인식에 더 가깝고, 
    # 색상 차이를 유클리드 거리로 측정하기에 적합합니다.
    lab1 = cv2.cvtColor(img1, cv2.COLOR_BGR2LAB)
    lab2 = cv2.cvtColor(img2, cv2.COLOR_BGR2LAB)
    
    # 각 채널에 블러 적용
    lab1_blur = cv2.GaussianBlur(lab1, blur_size, 0)
    lab2_blur = cv2.GaussianBlur(lab2, blur_size, 0)
    
    # LAB 채널별 차이 계산 후 합성
    # L: 밝기, A: 녹색-빨간색, B: 파란색-노란색
    lab_diff = cv2.absdiff(lab1_blur, lab2_blur)
    
    # 각 채널의 차이를 합산 (색상 변화가 큰 영역 감지)
    # A, B 채널에 더 높은 가중치 (색상 차이 강조)
    color_diff = (
        lab_diff[:, :, 0].astype(np.float32) * 0.3 +  # L 채널 (밝기)
        lab_diff[:, :, 1].astype(np.float32) * 0.5 +  # A 채널 (녹-적)
        lab_diff[:, :, 2].astype(np.float32) * 0.5    # B 채널 (청-황)
    )
    color_diff = np.clip(color_diff, 0, 255).astype(np.uint8)
    
    # 임계값 적용
    _, color_mask = cv2.threshold(
        color_diff, config.color_threshold, 255, cv2.THRESH_BINARY
    )
    
    # -------------------------------------------------------------------------
    # 3. 마스크 결합 (OR 연산)
    # -------------------------------------------------------------------------
    # 그레이스케일 또는 색상 차이가 있으면 감지
    combined_mask = cv2.bitwise_or(gray_mask, color_mask)
    
    # -------------------------------------------------------------------------
    # 4. Morphological 연산으로 노이즈 제거 및 영역 정리
    # -------------------------------------------------------------------------
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, 
        (config.morph_kernel_size, config.morph_kernel_size)
    )
    
    # Opening: 작은 노이즈 점 제거 (침식 후 팽창)
    # → False Positive 감소 (야자수 잎 같은 미세한 차이 제거)
    cleaned_mask = cv2.morphologyEx(
        combined_mask, cv2.MORPH_OPEN, kernel, 
        iterations=config.open_iterations
    )
    
    # Closing: 작은 구멍 메우기 (팽창 후 침식)
    # → 큰 차이 영역 내의 작은 빈틈 채우기
    cleaned_mask = cv2.morphologyEx(
        cleaned_mask, cv2.MORPH_CLOSE, kernel, 
        iterations=config.close_iterations
    )
    
    return cleaned_mask


# ============================================================================
# 📦 컨투어 검출 및 필터링
# ============================================================================

def find_and_filter_contours(
    binary_mask: np.ndarray, 
    min_area: int = 150
) -> List[np.ndarray]:
    """
    이진 마스크에서 컨투어를 찾고 면적으로 필터링합니다.
    
    Args:
        binary_mask: 이진 마스크 이미지
        min_area: 최소 컨투어 면적 (이보다 작으면 무시)
    
    Returns:
        필터링된 컨투어 리스트
    """
    contours, _ = cv2.findContours(
        binary_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )
    
    # 최소 면적 이상의 컨투어만 선택
    filtered = [cnt for cnt in contours if cv2.contourArea(cnt) >= min_area]
    
    return filtered


def get_bounding_boxes(contours: List[np.ndarray]) -> List[Tuple[int, int, int, int]]:
    """
    컨투어에서 바운딩 박스를 추출합니다.
    
    Args:
        contours: 컨투어 리스트
    
    Returns:
        (x, y, width, height) 튜플 리스트
    """
    return [cv2.boundingRect(cnt) for cnt in contours]


# ============================================================================
# 🔗 바운딩 박스 병합 (Union-Find 알고리즘)
# ============================================================================

class UnionFind:
    """
    Union-Find (Disjoint Set) 자료구조
    효율적인 그룹 병합을 위해 사용
    """
    def __init__(self, n: int):
        self.parent = list(range(n))
        self.rank = [0] * n
    
    def find(self, x: int) -> int:
        """경로 압축을 사용한 루트 찾기"""
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent[x]
    
    def union(self, x: int, y: int) -> None:
        """랭크 기반 합집합"""
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
    """
    두 바운딩 박스가 지정된 거리 이내인지 확인합니다.
    
    Args:
        box1: (x, y, w, h) 첫 번째 박스
        box2: (x, y, w, h) 두 번째 박스
        distance: 병합 거리 임계값
    
    Returns:
        두 박스가 가까우면 True
    """
    x1, y1, w1, h1 = box1
    x2, y2, w2, h2 = box2
    
    # 박스 1의 경계 (distance만큼 확장)
    left1, right1 = x1 - distance, x1 + w1 + distance
    top1, bottom1 = y1 - distance, y1 + h1 + distance
    
    # 박스 2의 경계
    left2, right2 = x2, x2 + w2
    top2, bottom2 = y2, y2 + h2
    
    # 확장된 박스 1과 박스 2가 겹치는지 확인
    horizontal_overlap = left1 < right2 and right1 > left2
    vertical_overlap = top1 < bottom2 and bottom1 > top2
    
    return horizontal_overlap and vertical_overlap


def merge_bounding_boxes(
    boxes: List[Tuple[int, int, int, int]], 
    merge_distance: int = 30
) -> List[Tuple[int, int, int, int]]:
    """
    가까운 바운딩 박스들을 병합합니다.
    
    Union-Find 알고리즘을 사용하여 효율적으로 그룹핑합니다.
    
    Args:
        boxes: 바운딩 박스 리스트 (x, y, w, h)
        merge_distance: 병합 거리 임계값 (픽셀)
    
    Returns:
        병합된 바운딩 박스 리스트
    """
    if not boxes:
        return []
    
    n = len(boxes)
    uf = UnionFind(n)
    
    # 가까운 박스들을 같은 그룹으로 묶기
    for i in range(n):
        for j in range(i + 1, n):
            if boxes_are_close(boxes[i], boxes[j], merge_distance):
                uf.union(i, j)
    
    # 그룹별로 박스 모으기
    groups: Dict[int, List[int]] = {}
    for i in range(n):
        root = uf.find(i)
        if root not in groups:
            groups[root] = []
        groups[root].append(i)
    
    # 각 그룹의 박스들을 하나로 병합
    merged_boxes = []
    for indices in groups.values():
        # 그룹 내 모든 박스를 포함하는 최소 바운딩 박스 계산
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
    """
    바운딩 박스에 패딩을 추가합니다.
    
    Args:
        boxes: 바운딩 박스 리스트
        padding: 추가할 패딩 (픽셀)
        img_width: 이미지 너비
        img_height: 이미지 높이
    
    Returns:
        패딩이 추가된 바운딩 박스 리스트
    """
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
    """
    바운딩 박스를 JSON 형식으로 변환합니다.
    
    Args:
        boxes: 바운딩 박스 리스트
        img_width: 이미지 너비
        img_height: 이미지 높이
    
    Returns:
        JSON 직렬화 가능한 딕셔너리 리스트
    """
    result = []
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        # 중심점 계산
        center_x = x + w // 2
        center_y = y + h // 2
        
        # 비율 좌표 계산 (Flutter 앱용)
        relative_x = round(center_x / img_width, 4)
        relative_y = round(center_y / img_height, 4)
        
        # 반경 계산 (더 큰 축 기준, 20% 여유 추가)
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
    mask: Optional[np.ndarray] = None,
    output_path: str = "debug.jpg"
) -> None:
    """
    디버그용 이미지를 생성하고 저장합니다.
    
    Args:
        original: 원본 이미지
        boxes: 바운딩 박스 리스트
        mask: 차이 마스크 (선택, 제공 시 함께 저장)
        output_path: 출력 파일 경로
    """
    debug_img = original.copy()
    
    for idx, (x, y, w, h) in enumerate(boxes, start=1):
        # 빨간색 바운딩 박스
        cv2.rectangle(debug_img, (x, y), (x + w, y + h), (0, 0, 255), 3)
        
        # 번호 라벨 (배경 포함)
        label = str(idx)
        (label_w, label_h), baseline = cv2.getTextSize(
            label, cv2.FONT_HERSHEY_SIMPLEX, 0.8, 2
        )
        cv2.rectangle(
            debug_img, 
            (x, y - label_h - 10), 
            (x + label_w + 10, y), 
            (0, 0, 255), -1
        )
        cv2.putText(
            debug_img, label, (x + 5, y - 5), 
            cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2
        )
        
        # 중심점 (녹색)
        center_x = x + w // 2
        center_y = y + h // 2
        cv2.circle(debug_img, (center_x, center_y), 5, (0, 255, 0), -1)
    
    # 이미지 저장
    cv2.imwrite(output_path, debug_img)
    print(f"✅ 디버그 이미지 저장: {output_path}")
    
    # 마스크도 저장 (제공된 경우)
    if mask is not None:
        mask_path = output_path.replace('.jpg', '_mask.jpg').replace('.png', '_mask.png')
        cv2.imwrite(mask_path, mask)
        print(f"✅ 마스크 이미지 저장: {mask_path}")


# ============================================================================
# 🚀 메인 분석 함수
# ============================================================================

def find_differences(
    original_path: str, 
    diff_path: str, 
    output_json_path: Optional[str] = None,
    output_debug_path: Optional[str] = None,
    config: Optional[Config] = None,
    save_mask: bool = True
) -> List[Dict]:
    """
    두 이미지를 비교하여 다른 부분을 찾습니다.
    
    Args:
        original_path: 원본 이미지 경로
        diff_path: 틀린그림 이미지 경로
        output_json_path: 결과 JSON 파일 경로 (선택)
        output_debug_path: 디버그 이미지 경로 (선택)
        config: 분석 설정 (기본값 사용 시 None)
        save_mask: 마스크 이미지 저장 여부
    
    Returns:
        다른 부분의 좌표 정보 리스트
    """
    if config is None:
        config = DEFAULT_CONFIG
    
    print(f"\n{'='*60}")
    print(f"🔍 이미지 분석 시작")
    print(f"{'='*60}")
    print(f"   원본: {original_path}")
    print(f"   틀린그림: {diff_path}")
    print(f"\n📊 설정:")
    print(f"   - Blur 커널: {config.blur_kernel_size}")
    print(f"   - 그레이 임계값: {config.gray_threshold}")
    print(f"   - 색상 임계값: {config.color_threshold}")
    print(f"   - 최소 면적: {config.min_contour_area}")
    print(f"   - 병합 거리: {config.merge_distance}")
    
    # 1. 이미지 로드
    original, diff = load_images(original_path, diff_path)
    img_height, img_width = original.shape[:2]
    print(f"\n📐 이미지 크기: {img_width} x {img_height}")
    
    # 2. 차이 마스크 계산
    print(f"\n🎨 차이 마스크 계산 중...")
    binary_mask = compute_difference_mask(original, diff, config)
    
    # 3. 컨투어 찾기
    contours = find_and_filter_contours(binary_mask, config.min_contour_area)
    print(f"   → 발견된 컨투어: {len(contours)}개")
    
    # 4. 바운딩 박스 추출
    boxes = get_bounding_boxes(contours)
    
    # 5. 가까운 박스 병합
    merged_boxes = merge_bounding_boxes(boxes, config.merge_distance)
    print(f"   → 병합 후 영역: {len(merged_boxes)}개")
    
    # 6. 패딩 추가
    final_boxes = add_padding_to_boxes(
        merged_boxes, config.bbox_padding, img_width, img_height
    )
    
    # 7. JSON 형식으로 변환
    result = boxes_to_json(final_boxes, img_width, img_height)
    
    # 8. JSON 파일 저장
    if output_json_path:
        with open(output_json_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        print(f"\n✅ JSON 저장: {output_json_path}")
    
    # 9. 디버그 이미지 저장
    if output_debug_path:
        draw_debug_image(
            original, final_boxes, 
            mask=binary_mask if save_mask else None,
            output_path=output_debug_path
        )
    
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
# 📁 배치 처리 (모든 스테이지)
# ============================================================================

def process_all_stages(
    assets_dir: str, 
    output_dir: Optional[str] = None,
    config: Optional[Config] = None
) -> Dict[str, List[Dict]]:
    """
    모든 스테이지 이미지를 일괄 처리합니다.
    
    Args:
        assets_dir: 이미지 파일이 있는 디렉토리
        output_dir: 결과 저장 디렉토리 (기본: assets_dir/../spot_results)
        config: 분석 설정
    
    Returns:
        {스테이지명: [스팟정보]} 형태의 딕셔너리
    """
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(assets_dir), "spot_results")
    
    os.makedirs(output_dir, exist_ok=True)
    
    all_results = {}
    
    # PNG 파일 찾기 (원본만)
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
                config=config
            )
            all_results[stage_name] = result
        except Exception as e:
            print(f"❌ {stage_name}: 오류 발생 - {e}")
    
    # 전체 결과 저장
    all_results_path = os.path.join(output_dir, "all_spots.json")
    with open(all_results_path, 'w', encoding='utf-8') as f:
        json.dump(all_results, f, indent=2, ensure_ascii=False)
    print(f"\n✅ 전체 결과 저장: {all_results_path}")
    
    # Flutter Dart 코드 생성
    dart_code = generate_dart_code(all_results)
    dart_path = os.path.join(output_dir, "spot_data.dart")
    with open(dart_path, 'w', encoding='utf-8') as f:
        f.write(dart_code)
    print(f"✅ Dart 코드 저장: {dart_path}")
    
    return all_results


def generate_dart_code(results: Dict[str, List[Dict]]) -> str:
    """
    Flutter 앱용 Dart 코드를 생성합니다.
    
    Args:
        results: {스테이지명: [스팟정보]} 딕셔너리
    
    Returns:
        Dart 코드 문자열
    """
    lines = [
        "// 자동 생성된 스팟 데이터",
        "// 생성 스크립트: find_differences_v2.py",
        "//",
        "// 사용법:",
        "//   spot_difference_data.dart 파일의 _spotData 맵에",
        "//   아래 내용을 복사하여 붙여넣으세요.",
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
        description='틀린그림찾기 이미지 분석 스크립트 v2.0',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  # 단일 이미지 쌍 분석
  python3 find_differences_v2.py -o 1-1.png -d 1-1-wrong.png

  # 모든 스테이지 일괄 처리
  python3 find_differences_v2.py --all ../assets/soptTheDifference

  # 높은 민감도로 분석 (미세한 차이 감지)
  python3 find_differences_v2.py --all ../assets/soptTheDifference -s high

  # 커스텀 파라미터
  python3 find_differences_v2.py -o img.png -d img-wrong.png -t 35 -m 200 --merge 40

민감도 프리셋:
  low       - 큰 차이만, 노이즈 최소화
  medium    - 일반적인 차이 (기본값)
  high      - 작은 차이도 감지
  very_high - 매우 미세한 차이까지 감지
        """
    )
    
    # 입력 옵션
    parser.add_argument('-o', '--original', type=str, help='원본 이미지 경로')
    parser.add_argument('-d', '--diff', type=str, help='틀린그림 이미지 경로')
    parser.add_argument('-a', '--all', type=str, help='모든 스테이지 처리 (이미지 폴더 경로)')
    
    # 출력 옵션
    parser.add_argument('--output', type=str, help='결과 JSON 파일 경로')
    parser.add_argument('--debug', type=str, help='디버그 이미지 경로')
    
    # 파라미터 옵션
    parser.add_argument('-s', '--sensitivity', type=str, default='medium',
                        choices=['low', 'medium', 'high', 'very_high'],
                        help='민감도 프리셋 (기본: medium). low=큰 차이만, very_high=미세한 차이도')
    parser.add_argument('-t', '--threshold', type=int, default=None,
                        help='그레이스케일 차이 임계값 (프리셋 무시)')
    parser.add_argument('-c', '--color-threshold', type=int, default=None,
                        help='색상 차이 임계값 (프리셋 무시)')
    parser.add_argument('-m', '--min-area', type=int, default=None,
                        help='최소 컨투어 면적 (프리셋 무시)')
    parser.add_argument('--merge', type=int, default=None,
                        help='박스 병합 거리 (프리셋 무시)')
    parser.add_argument('-b', '--blur', type=int, default=5,
                        help='Blur 커널 크기 (기본: 5, 홀수)')
    
    args = parser.parse_args()
    
    # 민감도 프리셋에서 시작
    config = SENSITIVITY_PRESETS.get(args.sensitivity, SENSITIVITY_PRESETS['medium'])
    
    # 개별 파라미터로 덮어쓰기 (지정된 경우만)
    if args.threshold is not None:
        config = Config(
            blur_kernel_size=config.blur_kernel_size,
            gray_threshold=args.threshold,
            color_threshold=config.color_threshold,
            morph_kernel_size=config.morph_kernel_size,
            open_iterations=config.open_iterations,
            close_iterations=config.close_iterations,
            min_contour_area=config.min_contour_area,
            merge_distance=config.merge_distance,
            bbox_padding=config.bbox_padding
        )
    if args.color_threshold is not None:
        config = Config(
            blur_kernel_size=config.blur_kernel_size,
            gray_threshold=config.gray_threshold,
            color_threshold=args.color_threshold,
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
            gray_threshold=config.gray_threshold,
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
            gray_threshold=config.gray_threshold,
            color_threshold=config.color_threshold,
            morph_kernel_size=config.morph_kernel_size,
            open_iterations=config.open_iterations,
            close_iterations=config.close_iterations,
            min_contour_area=config.min_contour_area,
            merge_distance=args.merge,
            bbox_padding=config.bbox_padding
        )
    if args.blur != 5:
        config = Config(
            blur_kernel_size=args.blur if args.blur % 2 == 1 else args.blur + 1,
            gray_threshold=config.gray_threshold,
            color_threshold=config.color_threshold,
            morph_kernel_size=config.morph_kernel_size,
            open_iterations=config.open_iterations,
            close_iterations=config.close_iterations,
            min_contour_area=config.min_contour_area,
            merge_distance=config.merge_distance,
            bbox_padding=config.bbox_padding
        )
    
    if args.all:
        # 모든 스테이지 일괄 처리
        process_all_stages(args.all, config=config)
    elif args.original and args.diff:
        # 단일 이미지 쌍 처리
        output_json = args.output or "result.json"
        output_debug = args.debug or "result_debug.jpg"
        
        find_differences(
            original_path=args.original,
            diff_path=args.diff,
            output_json_path=output_json,
            output_debug_path=output_debug,
            config=config
        )
    else:
        parser.print_help()
        print("\n" + "="*60)
        print("💡 빠른 시작:")
        print("="*60)
        print("  # 모든 스테이지 분석 (기본 민감도)")
        print("  python3 find_differences_v2.py --all ../assets/soptTheDifference")
        print("")
        print("  # 미세한 차이도 감지 (높은 민감도)")
        print("  python3 find_differences_v2.py --all ../assets/soptTheDifference -s high")
        print("")
        print("  # 단일 이미지 분석")
        print("  python3 find_differences_v2.py -o img.png -d img-wrong.png")
        print("")
        print("📊 민감도 프리셋:")
        print("  low       - 큰 차이만 감지 (노이즈 최소화)")
        print("  medium    - 일반적인 차이 감지 (기본값)")
        print("  high      - 작은 차이도 감지")
        print("  very_high - 매우 미세한 차이까지 감지")


if __name__ == "__main__":
    main()
