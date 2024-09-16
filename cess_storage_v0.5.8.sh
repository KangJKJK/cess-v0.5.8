#!/bin/bash

# 컬러 정의
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export GREEN='\033[0;32m'
export NC='\033[0m'  # No Color

# 함수: 명령어 실행 및 결과 확인, 오류 발생 시 사용자에게 계속 진행할지 묻기
execute_with_prompt() {
    local message="$1"
    local command="$2"
    echo -e "${YELLOW}${message}${NC}"
    echo "Executing: $command"
    
    # 명령어 실행 및 오류 내용 캡처
    output=$(eval "$command" 2>&1)
    exit_code=$?

    # 출력 결과를 화면에 표시
    echo "$output"

    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Error: Command failed: $command${NC}" >&2
        echo -e "${RED}Detailed Error Message:${NC}"
        echo "$output" | sed 's/^/  /'  # 상세 오류 메시지를 들여쓰기하여 출력
        echo

        # 사용자에게 계속 진행할지 묻기
        read -p "오류가 발생했습니다. 계속 진행하시겠습니까? (Y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}스크립트를 종료합니다.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Success: Command completed successfully.${NC}"
    fi
}

# 안내 메시지
echo -e "${YELLOW}설치 도중 문제가 발생하면 다음 명령어를 입력하고 다시 시도하세요:${NC}"
echo -e "${YELLOW}sudo rm -f /root/cess_storage_v0.5.8.sh${NC}"
echo

#!/bin/bash

# 최적화 스크립트

echo -e "${GREEN}시스템 최적화 작업을 시작합니다.${NC}"

# 불필요한 패키지 자동 제거
echo -e "${GREEN}불필요한 패키지 자동 제거 중...${NC}"
sudo apt autoremove -y

# .deb 파일 삭제
echo -e "${GREEN}.deb 파일 삭제 중...${NC}"
sudo rm /root/*.deb

# 패키지 캐시 정리
echo -e "${GREEN}패키지 캐시 정리 중...${NC}"
sudo apt-get clean

# /tmp 디렉토리 비우기
echo -e "${GREEN}/tmp 디렉토리 비우기 중...${NC}"
sudo rm -rf /tmp/*

# 사용자 캐시 비우기
echo -e "${GREEN}사용자 캐시 비우기 중...${NC}"
rm -rf ~/.cache/*

# .sh 및 .rz 파일 삭제
echo -e "${GREEN}.sh 및 .rz 파일 삭제 중...${NC}"
sudo rm -f /root/*.sh /root/*.rz

# Docker가 설치되어 있는지 확인
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}Docker가 설치되어 있습니다. Docker 관련 작업을 수행합니다.${NC}"

    # Docker 로그 정리 스크립트 작성
    echo -e "${GREEN}Docker 로그 정리 스크립트 작성 중...${NC}"
    echo -e '#!/bin/bash\ndocker ps -q | xargs -I {} docker logs --tail 0 {} > /dev/null' | sudo tee /usr/local/bin/docker-log-cleanup.sh
    sudo chmod +x /usr/local/bin/docker-log-cleanup.sh

    # Docker 로그 정리 작업을 크론에 추가
    echo -e "${GREEN}크론 작업 추가 중...${NC}"
    (crontab -l ; echo '0 0 * * * /usr/local/bin/docker-log-cleanup.sh') | sudo crontab -

    # 중지된 모든 컨테이너 제거
    echo -e "${GREEN}중지된 모든 컨테이너 제거 중...${NC}"
    sudo docker container prune -f

    # 사용하지 않는 모든 이미지 제거
    echo -e "${GREEN}사용하지 않는 모든 이미지 제거 중...${NC}"
    sudo docker image prune -a -f

    # 사용하지 않는 모든 볼륨 제거
    echo -e "${GREEN}사용하지 않는 모든 볼륨 제거 중...${NC}"
    sudo docker volume prune -f

    # 사용하지 않는 모든 데이터 정리
    echo -e "${GREEN}사용하지 않는 모든 데이터 정리 중...${NC}"
    sudo docker system prune -a -f
else
    echo -e "${RED}Docker가 설치되어 있지 않습니다. Docker 관련 작업을 생략합니다.${NC}"
fi

echo -e "${GREEN}시스템 최적화 작업이 완료되었습니다.${NC}"

# 1. 패키지 업데이트 및 필요한 패키지 설치
execute_with_prompt "패키지 업데이트 및 필요한 패키지 설치 중..." \
    "sudo apt update && sudo apt install -y ca-certificates curl gnupg ufw && sudo apt install expect"

# 2. Docker GPG 키 및 저장소 설정
execute_with_prompt "Docker GPG 키 및 저장소 설정 중..." \
    "sudo mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

# 3. Docker 설치 (이미 설치된 경우를 처리)
echo -e "${YELLOW}Docker 설치 확인 중...${NC}"
if ! command -v docker &> /dev/null; then
    execute_with_prompt "Docker 설치 중..." \
        "sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io"
else
    echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
fi

# 4. Docker 서비스 활성화 및 시작
execute_with_prompt "Docker 서비스 활성화 및 시작 중..." \
    "sudo systemctl enable docker && sudo systemctl start docker"

# 5. UFW 설치 및 포트 개방
execute_with_prompt "UFW 설치 중..." "sudo apt-get install -y ufw"
read -p "UFW를 설치한 후 계속하려면 Enter를 누르세요..."
execute_with_prompt "UFW 활성화 중...반응이 없으면 엔터를 누르세요" "sudo ufw enable"
execute_with_prompt "필요한 포트 개방 중..." \
    "sudo ufw allow ssh && \
    sudo ufw allow 22 && \
    sudo ufw allow 4001 && \
    sudo ufw allow 4000/tcp && \
    sudo ufw allow 8001 && \
    sudo ufw allow 8001/tcp && \
    sudo ufw status"
sleep 2

# 6. CESS nodeadm 다운로드 및 설치
execute_with_prompt "CESSv0.5.8 다운로드 중..." \
    "wget https://github.com/CESSProject/cess-nodeadm/archive/v0.5.8.tar.gz"
execute_with_prompt "CESSv0.5.8 압축 해제 중..." \
    "tar -xvzf v0.5.8.tar.gz"

# CESS nodeadm 디렉토리로 이동
echo -e "${YELLOW}디렉토리 이동 시도 중...${NC}"
cd cess-nodeadm-0.5.8 || { echo -e "${RED}디렉토리 이동 실패${NC}"; exit 1; }
echo -e "${YELLOW}현재 디렉토리: $(pwd)${NC}"

execute_with_prompt "CESSv0.5.8 설치 중..." "sudo ./install.sh"

# 사용자 안내 메시지
echo -e "${RED}다음과 같은 안내 메시지가 나오면${NC} ${YELLOW}노란색${NC}${RED}과 같이 진행하세요:${NC}"

echo -e "${GREEN}1. Enter cess node mode from 'authority/storage/rpcnode'${NC}"
echo -e "${YELLOW}storage${NC}"
echo -e "${GREEN}2. Enter cess storage listener port${NC}"
echo -e "${YELLOW}엔터${NC}"
echo -e "${GREEN}3. Enter cess rpc ws-url${NC}"
echo -e "${YELLOW}엔터${NC}"
echo -e "${GREEN}4. Enter cess storage earnings account${NC}"
echo -e "${YELLOW}리워드를 받을 지갑 주소${NC}"
echo -e "${GREEN}5. Enter cess storage signature account phrase${NC}"
echo -e "${YELLOW}위와 다른 지갑의 복구문자${NC}"
echo -e "${GREEN}6. Enter cess storage disk path${NC}"
echo -e "${YELLOW}엔터${NC}"
echo -e "${GREEN}7. Enter cess storage space, by GB unit${NC}"
echo -e "${YELLOW}100${NC}"
echo -e "${GREEN}8. Enter the number of CPU cores used for mining${NC}"
echo -e "${YELLOW}Your CPU cores라고 나오는 숫자${NC}"
echo -e "${GREEN}9. Enter the staking account if you use one account to stake multiple nodes${NC}"
echo -e "${YELLOW}엔터${NC}"
echo -e "${GREEN}10. Enter the TEE worker endpoints if you have any${NC}"
echo -e "${YELLOW}엔터${NC}"

# 7. CESS 프로필 및 설정 구성

# CESS 프로필 설정
echo "프로필 설정 구성 중..."
sudo cess profile testnet

# 잠시 대기
sleep 2

# CESS 구성 설정
echo "CESS 구성 설정 중 (사용자 입력 필요)..."
# `stdbuf`를 사용하여 명령어의 출력을 실시간으로 처리합니다.
stdbuf -i0 -o0 -e0 sudo cess config set

echo "CESS 구성 완료."

# 8. CESS 노드 구동 및 Docker 로그 확인
execute_with_prompt "CESS 노드 구동 및 Docker 로그 확인 중..." \
    "sudo cess start && docker logs miner"

echo -e "${YELLOW}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}Cess wallet 생성: https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Ftestnet-rpc0.cess.cloud%2Fws%2F#/explorer${NC}"
echo -e "${GREEN}Faucet 주소: https://cess.network/faucet.html${NC}"
echo -e "${GREEN}노드구동 확인법: sudo cess miner stat && docker logs miner${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"

