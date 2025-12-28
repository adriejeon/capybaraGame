#!/usr/bin/env python3
"""
이미지 파일을 WebP 포맷으로 변환하는 스크립트

사용법:
    pip install Pillow
    python convert_images.py
"""

import os
import re
from pathlib import Path
from PIL import Image

# 프로젝트 루트 디렉토리
PROJECT_ROOT = Path(__file__).parent
ASSETS_DIR = PROJECT_ROOT / "assets"
LIB_DIR = PROJECT_ROOT / "lib"

# 변환할 이미지 확장자
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.PNG', '.JPG', '.JPEG'}

# WebP 변환 품질
WEBP_QUALITY = 80


def convert_image_to_webp(image_path: Path) -> bool:
    """
    이미지 파일을 WebP 포맷으로 변환
    
    Args:
        image_path: 변환할 이미지 파일 경로
        
    Returns:
        변환 성공 여부
    """
    try:
        # 이미지 열기
        with Image.open(image_path) as img:
            # RGBA 모드로 변환 (투명도 지원)
            if img.mode in ('RGBA', 'LA'):
                # 투명도가 있는 경우
                webp_path = image_path.with_suffix('.webp')
                img.save(webp_path, 'WEBP', quality=WEBP_QUALITY, method=6)
            elif img.mode == 'P':
                # 팔레트 모드인 경우 RGBA로 변환
                img = img.convert('RGBA')
                webp_path = image_path.with_suffix('.webp')
                img.save(webp_path, 'WEBP', quality=WEBP_QUALITY, method=6)
            else:
                # RGB 모드로 변환
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                webp_path = image_path.with_suffix('.webp')
                img.save(webp_path, 'WEBP', quality=WEBP_QUALITY, method=6)
        
        print(f"✓ 변환 완료: {image_path.name} -> {webp_path.name}")
        return True
    except Exception as e:
        print(f"✗ 변환 실패: {image_path.name} - {str(e)}")
        return False


def find_and_convert_images(directory: Path):
    """
    디렉토리를 재귀적으로 순회하며 이미지 파일을 찾아 WebP로 변환
    
    Args:
        directory: 검색할 디렉토리 경로
    """
    converted_count = 0
    failed_count = 0
    
    # 디렉토리 내 모든 파일 순회
    for root, dirs, files in os.walk(directory):
        for file in files:
            file_path = Path(root) / file
            
            # 이미지 확장자 확인
            if file_path.suffix in IMAGE_EXTENSIONS:
                # WebP로 변환
                if convert_image_to_webp(file_path):
                    # 변환 성공 시 원본 파일 삭제
                    try:
                        file_path.unlink()
                        converted_count += 1
                    except Exception as e:
                        print(f"✗ 원본 파일 삭제 실패: {file_path.name} - {str(e)}")
                        failed_count += 1
                else:
                    failed_count += 1
    
    print(f"\n변환 완료: {converted_count}개 성공, {failed_count}개 실패")


def update_dart_files(directory: Path):
    """
    Dart 파일 내의 이미지 경로 확장자를 .webp로 변경
    
    Args:
        directory: 검색할 디렉토리 경로
    """
    updated_files = []
    
    # 모든 .dart 파일 찾기
    for dart_file in directory.rglob("*.dart"):
        try:
            with open(dart_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # .png 확장자를 .webp로 변경
            # 문자열 내에서만 변경하도록 정규식 사용
            # 'assets/...png' 또는 "assets/...png" 패턴 매칭
            content = re.sub(
                r"(['\"])(assets/[^'\"]+\.png)\1",
                lambda m: f"{m.group(1)}{m.group(2)[:-4]}.webp{m.group(1)}",
                content
            )
            
            # .jpg 확장자를 .webp로 변경
            content = re.sub(
                r"(['\"])(assets/[^'\"]+\.jpg)\1",
                lambda m: f"{m.group(1)}{m.group(2)[:-4]}.webp{m.group(1)}",
                content
            )
            
            # .jpeg 확장자를 .webp로 변경
            content = re.sub(
                r"(['\"])(assets/[^'\"]+\.jpeg)\1",
                lambda m: f"{m.group(1)}{m.group(2)[:-5]}.webp{m.group(1)}",
                content
            )
            
            # 내용이 변경된 경우 파일 저장
            if content != original_content:
                with open(dart_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                updated_files.append(dart_file)
                print(f"✓ 업데이트: {dart_file.relative_to(PROJECT_ROOT)}")
        
        except Exception as e:
            print(f"✗ 파일 처리 실패: {dart_file} - {str(e)}")
    
    print(f"\nDart 파일 업데이트 완료: {len(updated_files)}개 파일 수정됨")


def main():
    """메인 함수"""
    print("=" * 60)
    print("이미지 WebP 변환 스크립트")
    print("=" * 60)
    
    # assets 디렉토리 확인
    if not ASSETS_DIR.exists():
        print(f"✗ 오류: assets 디렉토리를 찾을 수 없습니다: {ASSETS_DIR}")
        return
    
    # lib 디렉토리 확인
    if not LIB_DIR.exists():
        print(f"✗ 오류: lib 디렉토리를 찾을 수 없습니다: {LIB_DIR}")
        return
    
    print(f"\n1단계: 이미지 파일 변환 시작...")
    print(f"대상 디렉토리: {ASSETS_DIR}")
    find_and_convert_images(ASSETS_DIR)
    
    print(f"\n2단계: Dart 파일 내 이미지 경로 업데이트 시작...")
    print(f"대상 디렉토리: {LIB_DIR}")
    update_dart_files(LIB_DIR)
    
    print("\n" + "=" * 60)
    print("모든 작업이 완료되었습니다!")
    print("=" * 60)


if __name__ == "__main__":
    main()





