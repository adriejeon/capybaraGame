#!/usr/bin/env python3
"""
틀린그림찾기 파라미터 튜닝 GUI 도구 (배치 처리 모드)

실시간으로 파라미터를 조절하여 최적의 차이 감지 설정을 찾습니다.
색상 변화(예: 노란 오리 → 분홍 오리)도 감지할 수 있도록 컬러 이미지 기반 분석을 사용합니다.
하단 우측 모서리의 워터마크 영역은 자동으로 무시됩니다.

사용법:
    python3 diff_tuner_gui.py --batch
    python3 diff_tuner_gui.py --stage 2-3

키보드 단축키:
    S: 현재 결과 저장하고 다음 이미지 로드 (설정 유지)
    Q 또는 ESC: 모든 데이터를 diff_data.json에 저장하고 종료
    R: 파라미터 리셋

필요 라이브러리:
    pip install opencv-python numpy
"""

import cv2
import numpy as np
import json
import argparse
import os
import re
from pathlib import Path
from typing import List, Tuple, Dict, Optional


def natural_sort_key(stage_name: str) -> Tuple[int, int]:
    """논리적 정렬을 위한 키 함수 (1-1, 1-2, ..., 1-10, 2-1)"""
    match = re.match(r'(\d+)-(\d+)', stage_name)
    if match:
        return (int(match.group(1)), int(match.group(2)))
    return (0, 0)


def find_all_stage_pairs(assets_dir: Path) -> List[Tuple[str, Path, Path]]:
    """모든 스테이지 이미지 쌍을 찾아 논리적으로 정렬"""
    pairs = []
    
    # 원본 이미지 찾기
    for orig_file in sorted(assets_dir.glob("*.png")):
        if "-wrong" in orig_file.name:
            continue
        
        stage_name = orig_file.stem
        wrong_file = assets_dir / f"{stage_name}-wrong.png"
        
        if wrong_file.exists():
            pairs.append((stage_name, orig_file, wrong_file))
    
    # 논리적 정렬
    pairs.sort(key=lambda x: natural_sort_key(x[0]))
    
    return pairs


class DiffTunerGUI:
    def __init__(self, original_path: str, diff_path: str, stage_name: str, 
                 output_dir: str = None, roi_mask_percent: float = 0.12):
        self.original_path = original_path
        self.diff_path = diff_path
        self.stage_name = stage_name
        self.output_dir = output_dir or os.path.dirname(original_path)
        self.roi_mask_percent = roi_mask_percent  # 하단 우측 모서리 무시 비율 (12%)
        
        # 이미지 로드
        self.original = cv2.imread(original_path)
        self.diff_img = cv2.imread(diff_path)
        
        if self.original is None:
            raise ValueError(f"원본 이미지를 로드할 수 없습니다: {original_path}")
        if self.diff_img is None:
            raise ValueError(f"틀린그림 이미지를 로드할 수 없습니다: {diff_path}")
        
        # 이미지 크기 맞추기
        if self.original.shape != self.diff_img.shape:
            print(f"⚠️ 이미지 크기 조정: {self.diff_img.shape} → {self.original.shape}")
            self.diff_img = cv2.resize(self.diff_img, (self.original.shape[1], self.original.shape[0]))
        
        self.img_height, self.img_width = self.original.shape[:2]
        
        # ROI 마스크 영역 계산 (하단 우측 모서리)
        self.roi_x = int(self.img_width * (1 - self.roi_mask_percent))
        self.roi_y = int(self.img_height * (1 - self.roi_mask_percent))
        self.roi_width = self.img_width - self.roi_x
        self.roi_height = self.img_height - self.roi_y
        
        # 디스플레이용 리사이즈 (너무 크면 화면에 안 들어감)
        self.display_scale = 1.0
        max_display_height = 600
        if self.img_height > max_display_height:
            self.display_scale = max_display_height / self.img_height
        
        # 기본 파라미터
        self.default_params = {
            'threshold': 30,
            'blur_size': 3,
            'morph_size': 3,
            'min_area': 200,
            'merge_distance': 30,
            'color_threshold': 40,  # 색상 차이 임계값 (HSV 기반)
            'erode_size': 0,  # 연결된 객체 분리를 위한 Erosion 크기
        }
        
        # 현재 파라미터
        self.params = self.default_params.copy()
        
        # 윈도우 이름
        self.window_name = "Difference Tuner - Press 'S' to Save & Next, 'Q' to Quit"
        
        # 결과 저장용
        self.current_boxes = []  # 자동 감지된 박스
        self.manual_boxes = []  # 수동으로 추가한 박스 (녹색)
        self.removed_box_ids = set()  # 수동으로 제거한 박스 ID
        self.box_id_counter = 1000  # 수동 박스 ID (자동 박스와 구분)
        
    def create_trackbars(self):
        """트랙바 생성"""
        cv2.namedWindow(self.window_name, cv2.WINDOW_AUTOSIZE)
        
        # 마우스 콜백 등록
        cv2.setMouseCallback(self.window_name, self.mouse_callback)
        
        # 트랙바 생성
        cv2.createTrackbar('Threshold', self.window_name, self.params['threshold'], 255, self.on_trackbar)
        cv2.createTrackbar('Color Thresh', self.window_name, self.params['color_threshold'], 100, self.on_trackbar)
        cv2.createTrackbar('Blur Size', self.window_name, self.params['blur_size'], 20, self.on_trackbar)
        cv2.createTrackbar('Morph Size', self.window_name, self.params['morph_size'], 20, self.on_trackbar)
        cv2.createTrackbar('Erode Size', self.window_name, self.params['erode_size'], 10, self.on_trackbar)
        cv2.createTrackbar('Min Area', self.window_name, self.params['min_area'], 2000, self.on_trackbar)
        cv2.createTrackbar('Merge Dist', self.window_name, self.params['merge_distance'], 100, self.on_trackbar)
    
    def mouse_callback(self, event, x, y, flags, param):
        """마우스 이벤트 처리"""
        if event == cv2.EVENT_LBUTTONDOWN:
            # 왼쪽 클릭: 박스 추가
            self.add_manual_box(x, y)
        elif event == cv2.EVENT_RBUTTONDOWN:
            # 오른쪽 클릭: 박스 제거
            self.remove_box_at(x, y)
    
    def add_manual_box(self, display_x: int, display_y: int):
        """수동으로 박스 추가 (녹색)"""
        # 디스플레이 좌표를 원본 이미지 좌표로 변환
        # 이미지가 두 개 나란히 있으므로, 왼쪽 이미지(원본)만 고려
        display_width = int(self.img_width * self.display_scale * 2)  # 두 이미지 합친 너비
        
        # 왼쪽 이미지 영역인지 확인
        if display_x >= display_width // 2:
            # 오른쪽 이미지 클릭 시에도 왼쪽 이미지 좌표로 변환
            display_x = display_x - display_width // 2
        
        # 원본 이미지 좌표로 변환
        if self.display_scale < 1.0:
            orig_x = int(display_x / self.display_scale)
            orig_y = int(display_y / self.display_scale)
        else:
            orig_x = display_x
            orig_y = display_y
        
        # 이미지 범위 체크
        if orig_x < 0 or orig_x >= self.img_width or orig_y < 0 or orig_y >= self.img_height:
            return
        
        # 40x40 박스 생성 (중심점 기준)
        box_size = 40
        x = max(0, orig_x - box_size // 2)
        y = max(0, orig_y - box_size // 2)
        w = min(box_size, self.img_width - x)
        h = min(box_size, self.img_height - y)
        
        # 수동 박스 추가 (ID와 함께 저장)
        box_id = self.box_id_counter
        self.box_id_counter += 1
        self.manual_boxes.append((box_id, x, y, w, h))
        
        print(f"➕ 수동 박스 추가: ({x}, {y}, {w}x{h}) [ID: {box_id}]")
    
    def remove_box_at(self, display_x: int, display_y: int):
        """클릭 위치의 박스 제거"""
        # 디스플레이 좌표를 원본 이미지 좌표로 변환
        # 이미지가 두 개 나란히 있으므로, 왼쪽 이미지(원본)만 고려
        display_width = int(self.img_width * self.display_scale * 2)  # 두 이미지 합친 너비
        
        # 왼쪽 이미지 영역인지 확인
        if display_x >= display_width // 2:
            # 오른쪽 이미지 클릭 시에도 왼쪽 이미지 좌표로 변환
            display_x = display_x - display_width // 2
        
        # 원본 이미지 좌표로 변환
        if self.display_scale < 1.0:
            orig_x = int(display_x / self.display_scale)
            orig_y = int(display_y / self.display_scale)
        else:
            orig_x = display_x
            orig_y = display_y
        
        # 이미지 범위 체크
        if orig_x < 0 or orig_x >= self.img_width or orig_y < 0 or orig_y >= self.img_height:
            return
        
        # 자동 감지 박스 확인 (ID는 인덱스+1)
        for idx, (x, y, w, h) in enumerate(self.current_boxes, start=1):
            if x <= orig_x <= x + w and y <= orig_y <= y + h:
                if idx not in self.removed_box_ids:
                    self.removed_box_ids.add(idx)
                    print(f"➖ 자동 박스 제거: ID {idx} ({x}, {y}, {w}x{h})")
                    return
        
        # 수동 추가 박스 확인
        for i, (box_id, x, y, w, h) in enumerate(self.manual_boxes):
            if x <= orig_x <= x + w and y <= orig_y <= y + h:
                removed_box = self.manual_boxes.pop(i)
                print(f"➖ 수동 박스 제거: ID {removed_box[0]} ({x}, {y}, {w}x{h})")
                return
        
    def on_trackbar(self, val):
        """트랙바 값 변경 시 호출"""
        pass  # update_display에서 값을 읽음
    
    def read_trackbar_values(self):
        """트랙바에서 현재 값 읽기"""
        self.params['threshold'] = cv2.getTrackbarPos('Threshold', self.window_name)
        self.params['color_threshold'] = cv2.getTrackbarPos('Color Thresh', self.window_name)
        self.params['blur_size'] = cv2.getTrackbarPos('Blur Size', self.window_name)
        self.params['morph_size'] = cv2.getTrackbarPos('Morph Size', self.window_name)
        self.params['erode_size'] = cv2.getTrackbarPos('Erode Size', self.window_name)
        self.params['min_area'] = cv2.getTrackbarPos('Min Area', self.window_name)
        self.params['merge_distance'] = cv2.getTrackbarPos('Merge Dist', self.window_name)
        
        # blur_size는 홀수여야 함
        if self.params['blur_size'] < 1:
            self.params['blur_size'] = 1
        elif self.params['blur_size'] % 2 == 0:
            self.params['blur_size'] += 1
    
    def apply_roi_mask(self, mask: np.ndarray) -> np.ndarray:
        """하단 우측 모서리 영역을 마스크에서 제거 (워터마크 무시)"""
        masked = mask.copy()
        # ROI 영역을 0으로 설정
        masked[self.roi_y:, self.roi_x:] = 0
        return masked
    
    def compute_color_difference(self) -> np.ndarray:
        """컬러 이미지 기반 차이 계산 (색상 변화 감지)"""
        # Step 1: Gaussian Blur 적용
        blur_size = self.params['blur_size']
        blurred_orig = cv2.GaussianBlur(self.original, (blur_size, blur_size), 0)
        blurred_diff = cv2.GaussianBlur(self.diff_img, (blur_size, blur_size), 0)
        
        # Step 2: 컬러 이미지(BGR)에서 절대 차이 계산
        color_diff = cv2.absdiff(blurred_orig, blurred_diff)
        
        # Step 3: 그레이스케일로 변환하고 임계값 적용
        gray_diff = cv2.cvtColor(color_diff, cv2.COLOR_BGR2GRAY)
        _, binary_mask = cv2.threshold(gray_diff, self.params['threshold'], 255, cv2.THRESH_BINARY)
        
        # 추가: HSV 색공간에서도 차이 검출 (색상 변화 감지 강화)
        hsv_orig = cv2.cvtColor(blurred_orig, cv2.COLOR_BGR2HSV)
        hsv_diff = cv2.cvtColor(blurred_diff, cv2.COLOR_BGR2HSV)
        
        # Hue 채널 차이 (색상 변화)
        hue_diff = cv2.absdiff(hsv_orig[:,:,0], hsv_diff[:,:,0])
        # Hue는 원형이므로 180 이상 차이는 반대로 계산
        hue_diff = np.minimum(hue_diff, 180 - hue_diff)
        _, hue_mask = cv2.threshold(hue_diff, self.params['color_threshold'], 255, cv2.THRESH_BINARY)
        
        # Saturation 차이
        sat_diff = cv2.absdiff(hsv_orig[:,:,1], hsv_diff[:,:,1])
        _, sat_mask = cv2.threshold(sat_diff, self.params['color_threshold'], 255, cv2.THRESH_BINARY)
        
        # 모든 마스크 합치기
        combined_mask = cv2.bitwise_or(binary_mask, hue_mask)
        combined_mask = cv2.bitwise_or(combined_mask, sat_mask)
        
        # Step 4: ROI 마스크 적용 (워터마크 영역 제거)
        combined_mask = self.apply_roi_mask(combined_mask)
        
        # Step 5: Morphological Opening (노이즈 제거)
        morph_size = self.params['morph_size']
        if morph_size > 0:
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (morph_size, morph_size))
            combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_OPEN, kernel)
            # Closing으로 작은 구멍 채우기
            combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)
        
        # Step 6: Erosion (연결된 객체 분리)
        erode_size = self.params['erode_size']
        if erode_size > 0:
            kernel = np.ones((erode_size, erode_size), np.uint8)
            combined_mask = cv2.erode(combined_mask, kernel, iterations=1)
        
        return combined_mask
    
    def find_and_merge_boxes(self, binary_mask: np.ndarray) -> List[Tuple[int, int, int, int]]:
        """컨투어에서 바운딩 박스 추출 및 병합"""
        # 컨투어 찾기
        contours, _ = cv2.findContours(binary_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        # 최소 면적 필터링
        boxes = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area >= self.params['min_area']:
                x, y, w, h = cv2.boundingRect(cnt)
                boxes.append((x, y, w, h))
        
        # 가까운 박스 병합
        merged = self.merge_boxes(boxes, self.params['merge_distance'])
        
        return merged
    
    def merge_boxes(self, boxes: List[Tuple[int, int, int, int]], 
                    distance: int) -> List[Tuple[int, int, int, int]]:
        """가까운 박스들을 병합"""
        if not boxes:
            return []
        
        def boxes_close(box1, box2, dist):
            x1, y1, w1, h1 = box1
            x2, y2, w2, h2 = box2
            
            # 박스 확장해서 겹치는지 확인
            x1_ext = x1 - dist
            y1_ext = y1 - dist
            w1_ext = w1 + 2 * dist
            h1_ext = h1 + 2 * dist
            
            return (x1_ext < x2 + w2 and x1_ext + w1_ext > x2 and
                    y1_ext < y2 + h2 and y1_ext + h1_ext > y2)
        
        def merge_two(box1, box2):
            x1, y1, w1, h1 = box1
            x2, y2, w2, h2 = box2
            
            x_min = min(x1, x2)
            y_min = min(y1, y2)
            x_max = max(x1 + w1, x2 + w2)
            y_max = max(y1 + h1, y2 + h2)
            
            return (x_min, y_min, x_max - x_min, y_max - y_min)
        
        merged = list(boxes)
        changed = True
        
        while changed:
            changed = False
            new_merged = []
            used = [False] * len(merged)
            
            for i in range(len(merged)):
                if used[i]:
                    continue
                
                current = merged[i]
                
                for j in range(i + 1, len(merged)):
                    if used[j]:
                        continue
                    
                    if boxes_close(current, merged[j], distance):
                        current = merge_two(current, merged[j])
                        used[j] = True
                        changed = True
                
                new_merged.append(current)
                used[i] = True
            
            merged = new_merged
        
        return merged
    
    def draw_result(self, boxes: List[Tuple[int, int, int, int]]) -> np.ndarray:
        """결과 이미지 생성 (원본과 틀린그림 나란히)"""
        # 원본에 박스 그리기
        result_orig = self.original.copy()
        result_diff = self.diff_img.copy()
        
        # ROI 영역 표시 (파란색 박스와 X)
        roi_color = (255, 0, 0)  # 파란색 (BGR)
        cv2.rectangle(result_orig, (self.roi_x, self.roi_y), 
                     (self.img_width, self.img_height), roi_color, 3)
        cv2.rectangle(result_diff, (self.roi_x, self.roi_y), 
                     (self.img_width, self.img_height), roi_color, 3)
        
        # X 표시
        x_thickness = 3
        cv2.line(result_orig, (self.roi_x, self.roi_y), 
                (self.img_width, self.img_height), roi_color, x_thickness)
        cv2.line(result_orig, (self.img_width, self.roi_y), 
                (self.roi_x, self.img_height), roi_color, x_thickness)
        cv2.line(result_diff, (self.roi_x, self.roi_y), 
                (self.img_width, self.img_height), roi_color, x_thickness)
        cv2.line(result_diff, (self.img_width, self.roi_y), 
                (self.roi_x, self.img_height), roi_color, x_thickness)
        
        # "IGNORED" 텍스트
        text_x = self.roi_x + 10
        text_y = self.roi_y + 30
        cv2.putText(result_orig, "IGNORED", (text_x, text_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, roi_color, 2)
        cv2.putText(result_diff, "IGNORED", (text_x, text_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, roi_color, 2)
        
        # 자동 감지 박스 그리기 (빨간색) - 제거된 것은 제외
        box_idx = 1
        for x, y, w, h in boxes:
            if box_idx not in self.removed_box_ids:
                # 빨간색 박스
                cv2.rectangle(result_orig, (x, y), (x + w, y + h), (0, 0, 255), 2)
                cv2.rectangle(result_diff, (x, y), (x + w, y + h), (0, 0, 255), 2)
                
                # 번호
                cv2.putText(result_orig, str(box_idx), (x + 5, y + 25), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(result_diff, str(box_idx), (x + 5, y + 25), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                
                # 중심점
                cx, cy = x + w // 2, y + h // 2
                cv2.circle(result_orig, (cx, cy), 4, (0, 255, 0), -1)
                cv2.circle(result_diff, (cx, cy), 4, (0, 255, 0), -1)
            box_idx += 1
        
        # 수동 추가 박스 그리기 (녹색)
        manual_idx = len(boxes) + 1
        for box_id, x, y, w, h in self.manual_boxes:
            # 녹색 박스
            cv2.rectangle(result_orig, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.rectangle(result_diff, (x, y), (x + w, y + h), (0, 255, 0), 2)
            
            # 번호 (M 표시로 수동 박스임을 표시)
            cv2.putText(result_orig, f"M{manual_idx}", (x + 5, y + 25), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.putText(result_diff, f"M{manual_idx}", (x + 5, y + 25), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            # 중심점
            cx, cy = x + w // 2, y + h // 2
            cv2.circle(result_orig, (cx, cy), 4, (0, 255, 0), -1)
            cv2.circle(result_diff, (cx, cy), 4, (0, 255, 0), -1)
            manual_idx += 1
        
        # 두 이미지 합치기
        combined = np.hstack([result_orig, result_diff])
        
        return combined
    
    def update_display(self):
        """디스플레이 업데이트"""
        self.read_trackbar_values()
        
        # 차이 계산
        binary_mask = self.compute_color_difference()
        
        # 박스 찾기
        self.current_boxes = self.find_and_merge_boxes(binary_mask)
        
        # 결과 이미지 생성
        result = self.draw_result(self.current_boxes)
        
        # 마스크도 표시 (디버그용)
        mask_colored = cv2.cvtColor(binary_mask, cv2.COLOR_GRAY2BGR)
        
        # 정보 텍스트 추가
        final_box_count = len(self.get_final_boxes())
        auto_count = len([b for i, b in enumerate(self.current_boxes, 1) if i not in self.removed_box_ids])
        manual_count = len(self.manual_boxes)
        info_text = f"Stage: {self.stage_name} | Total: {final_box_count} (Auto: {auto_count}, Manual: {manual_count}) | Threshold: {self.params['threshold']} | Color: {self.params['color_threshold']} | Blur: {self.params['blur_size']} | Morph: {self.params['morph_size']} | Erode: {self.params['erode_size']} | MinArea: {self.params['min_area']} | MergeDist: {self.params['merge_distance']}"
        cv2.putText(result, info_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
        cv2.putText(result, "Left Click: Add Box | Right Click: Remove Box | 'S': Save & Next | 'Q': Quit & Save All | 'R': Reset", (10, 60), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
        
        # 리사이즈
        if self.display_scale < 1.0:
            h = int(result.shape[0] * self.display_scale)
            w = int(result.shape[1] * self.display_scale)
            result = cv2.resize(result, (w, h))
            
            mask_h = int(mask_colored.shape[0] * self.display_scale)
            mask_w = int(mask_colored.shape[1] * self.display_scale)
            mask_colored = cv2.resize(mask_colored, (mask_w, mask_h))
        
        cv2.imshow(self.window_name, result)
        cv2.imshow("Mask (Binary)", mask_colored)
    
    def get_final_boxes(self) -> List[Tuple[int, int, int, int]]:
        """최종 박스 리스트 계산: 자동 감지 박스 - 제거된 박스 + 수동 추가 박스"""
        final_boxes = []
        
        # 자동 감지 박스에서 제거되지 않은 것만 추가
        for idx, box in enumerate(self.current_boxes, start=1):
            if idx not in self.removed_box_ids:
                final_boxes.append(box)
        
        # 수동 추가 박스 추가
        for box_id, x, y, w, h in self.manual_boxes:
            final_boxes.append((x, y, w, h))
        
        return final_boxes
    
    def boxes_to_json(self) -> List[Dict]:
        """현재 박스를 JSON 형식으로 변환 (간단한 형식)"""
        final_boxes = self.get_final_boxes()
        result = []
        for x, y, w, h in final_boxes:
            result.append({
                "x": x,
                "y": y,
                "width": w,
                "height": h
            })
        return result
    
    def get_current_result(self) -> Dict:
        """현재 스테이지의 결과 반환"""
        return {
            self.stage_name: self.boxes_to_json()
        }
    
    def reset_params(self):
        """파라미터 리셋"""
        self.params = self.default_params.copy()
        cv2.setTrackbarPos('Threshold', self.window_name, self.params['threshold'])
        cv2.setTrackbarPos('Color Thresh', self.window_name, self.params['color_threshold'])
        cv2.setTrackbarPos('Blur Size', self.window_name, self.params['blur_size'])
        cv2.setTrackbarPos('Morph Size', self.window_name, self.params['morph_size'])
        cv2.setTrackbarPos('Erode Size', self.window_name, self.params['erode_size'])
        cv2.setTrackbarPos('Min Area', self.window_name, self.params['min_area'])
        cv2.setTrackbarPos('Merge Dist', self.window_name, self.params['merge_distance'])
        print("🔄 파라미터가 기본값으로 리셋되었습니다.")
    
    def load_new_images(self, original_path: str, diff_path: str, stage_name: str):
        """새로운 이미지 쌍 로드 (트랙바 설정 유지)"""
        self.original_path = original_path
        self.diff_path = diff_path
        self.stage_name = stage_name
        
        # 이미지 로드
        self.original = cv2.imread(original_path)
        self.diff_img = cv2.imread(diff_path)
        
        if self.original is None or self.diff_img is None:
            raise ValueError(f"이미지 로드 실패: {original_path} 또는 {diff_path}")
        
        # 이미지 크기 맞추기
        if self.original.shape != self.diff_img.shape:
            self.diff_img = cv2.resize(self.diff_img, (self.original.shape[1], self.original.shape[0]))
        
        self.img_height, self.img_width = self.original.shape[:2]
        
        # ROI 영역 재계산
        self.roi_x = int(self.img_width * (1 - self.roi_mask_percent))
        self.roi_y = int(self.img_height * (1 - self.roi_mask_percent))
        self.roi_width = self.img_width - self.roi_x
        self.roi_height = self.img_height - self.roi_y
        
        # 디스플레이 스케일 재계산
        self.display_scale = 1.0
        max_display_height = 600
        if self.img_height > max_display_height:
            self.display_scale = max_display_height / self.img_height
        
        # 새 이미지 로드 시 수동 박스와 제거된 박스 ID 초기화
        self.current_boxes = []
        self.manual_boxes = []
        self.removed_box_ids = set()
        print(f"✅ 다음 이미지 로드: {stage_name}")


class BatchProcessor:
    """배치 처리 관리자"""
    def __init__(self, assets_dir: Path, output_dir: Path):
        self.assets_dir = assets_dir
        self.output_dir = output_dir
        self.all_results = {}  # 모든 스테이지 결과 저장
        
        # 모든 스테이지 쌍 찾기
        self.stage_pairs = find_all_stage_pairs(assets_dir)
        self.current_index = 0
        
        if not self.stage_pairs:
            raise ValueError(f"이미지 쌍을 찾을 수 없습니다: {assets_dir}")
        
        print(f"📋 총 {len(self.stage_pairs)}개 스테이지 발견")
        for stage_name, _, _ in self.stage_pairs:
            print(f"   - {stage_name}")
    
    def get_current_stage(self) -> Optional[Tuple[str, Path, Path]]:
        """현재 스테이지 반환"""
        if self.current_index >= len(self.stage_pairs):
            return None
        return self.stage_pairs[self.current_index]
    
    def move_to_next(self):
        """다음 스테이지로 이동"""
        self.current_index += 1
        return self.current_index < len(self.stage_pairs)
    
    def save_result(self, stage_name: str, boxes: List[Dict]):
        """현재 스테이지 결과 저장"""
        self.all_results[stage_name] = boxes
        print(f"💾 저장됨: {stage_name} ({len(boxes)}개 차이점)")
    
    def save_all_to_json(self, output_path: Path):
        """모든 결과를 JSON 파일로 저장"""
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(self.all_results, f, indent=2, ensure_ascii=False)
        
        print("\n" + "="*60)
        print(f"✅ 모든 결과 저장 완료: {output_path}")
        print(f"📊 총 {len(self.all_results)}개 스테이지 처리됨")
        for stage_name, boxes in self.all_results.items():
            print(f"   {stage_name}: {len(boxes)}개 차이점")
        print("="*60 + "\n")


def run_batch_mode(assets_dir: Path, output_dir: Path):
    """배치 처리 모드 실행"""
    processor = BatchProcessor(assets_dir, output_dir)
    
    # 첫 번째 스테이지 로드
    stage_name, orig_path, diff_path = processor.get_current_stage()
    
    # GUI 초기화
    tuner = DiffTunerGUI(str(orig_path), str(diff_path), stage_name, str(output_dir))
    tuner.create_trackbars()
    
    print("\n🚀 배치 처리 모드 시작")
    print(f"   현재 스테이지: {stage_name} ({processor.current_index + 1}/{len(processor.stage_pairs)})")
    print("   - 트랙바를 조절하여 최적의 파라미터를 찾으세요")
    print("   - 'S': 현재 저장하고 다음 이미지 로드 (설정 유지)")
    print("   - 'Q' 또는 ESC: 모든 데이터 저장하고 종료")
    print("   - 'R': 파라미터 리셋\n")
    
    while True:
        tuner.update_display()
        
        key = cv2.waitKey(50) & 0xFF
        
        if key == ord('q') or key == 27:  # Q 또는 ESC
            # 현재 스테이지도 저장
            result = tuner.get_current_result()
            processor.save_result(stage_name, result[stage_name])
            
            # 모든 결과 저장
            output_json = output_dir / "diff_data.json"
            processor.save_all_to_json(output_json)
            print("👋 프로그램 종료")
            break
            
        elif key == ord('s') or key == ord('S'):
            # 현재 결과 저장
            result = tuner.get_current_result()
            processor.save_result(stage_name, result[stage_name])
            
            # 다음 스테이지로 이동
            if processor.move_to_next():
                next_stage_name, next_orig_path, next_diff_path = processor.get_current_stage()
                print(f"\n➡️ 다음 스테이지: {next_stage_name} ({processor.current_index + 1}/{len(processor.stage_pairs)})")
                
                # 새 이미지 로드 (트랙바 설정 유지)
                tuner.load_new_images(str(next_orig_path), str(next_diff_path), next_stage_name)
                stage_name = next_stage_name
            else:
                print("\n✅ 모든 스테이지 처리 완료!")
                # 모든 결과 저장
                output_json = output_dir / "diff_data.json"
                processor.save_all_to_json(output_json)
                break
                
        elif key == ord('r') or key == ord('R'):
            tuner.reset_params()
    
    cv2.destroyAllWindows()


def main():
    parser = argparse.ArgumentParser(description='틀린그림찾기 파라미터 튜닝 GUI 도구 (배치 처리 지원)')
    parser.add_argument('--batch', '-b', action='store_true', help='배치 처리 모드 (모든 스테이지 순차 처리)')
    parser.add_argument('--stage', '-s', type=str, help='단일 스테이지 이름 (예: 2-3)')
    parser.add_argument('--original', '-o', type=str, help='원본 이미지 경로')
    parser.add_argument('--diff', '-d', type=str, help='틀린그림 이미지 경로')
    parser.add_argument('--output', type=str, help='출력 디렉토리')
    
    args = parser.parse_args()
    
    # 스크립트 위치 기준 경로 설정
    script_dir = Path(__file__).parent
    assets_dir = script_dir.parent / "assets" / "soptTheDifference"
    output_dir = script_dir.parent / "assets" / "spot_results"
    
    if args.output:
        output_dir = Path(args.output)
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    if args.batch:
        # 배치 처리 모드
        if not assets_dir.exists():
            print(f"❌ 이미지 디렉토리를 찾을 수 없습니다: {assets_dir}")
            return
        
        run_batch_mode(assets_dir, output_dir)
        
    elif args.stage:
        # 단일 스테이지 모드
        original_path = assets_dir / f"{args.stage}.png"
        diff_path = assets_dir / f"{args.stage}-wrong.png"
        
        if not original_path.exists() or not diff_path.exists():
            print(f"❌ 이미지를 찾을 수 없습니다: {args.stage}")
            return
        
        tuner = DiffTunerGUI(str(original_path), str(diff_path), args.stage, str(output_dir))
        tuner.run()
        
    elif args.original and args.diff:
        # 직접 지정 모드
        original_path = Path(args.original)
        diff_path = Path(args.diff)
        stage_name = original_path.stem
        
        if not original_path.exists() or not diff_path.exists():
            print(f"❌ 이미지를 찾을 수 없습니다")
            return
        
        tuner = DiffTunerGUI(str(original_path), str(diff_path), stage_name, str(output_dir))
        tuner.run()
        
    else:
        print("사용법:")
        print("  배치 처리: python3 diff_tuner_gui.py --batch")
        print("  단일 스테이지: python3 diff_tuner_gui.py --stage 2-3")
        print("  직접 지정: python3 diff_tuner_gui.py --original orig.png --diff diff.png")
        print("\n사용 가능한 스테이지:")
        
        if assets_dir.exists():
            pairs = find_all_stage_pairs(assets_dir)
            for stage_name, _, _ in pairs[:10]:  # 처음 10개만 표시
                print(f"  - {stage_name}")
            if len(pairs) > 10:
                print(f"  ... 외 {len(pairs) - 10}개")


if __name__ == "__main__":
    main()
