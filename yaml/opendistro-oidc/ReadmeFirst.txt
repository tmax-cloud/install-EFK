1. hypercloud-root-ca.crt를 이용한 인증서, 키 생성
  a-1. elasticsearch 의 인증서, 키
    - 노드끼리의 통신
      : $ ./generateTls.sh -name=esnode -dns=opendistro-els.kube-logging.svc -dns=opendistro-els.kube-logging.svc.cluster.local
    - 단일 노드를 위한 것
      : $ ./generateTls.sh -name=opendistro-els-0
    - pem파일로 변환
      : $ cat esnode.key > esnode-k.pem
      : $ cat esnode.crt > esnode.pem
      : $ opendistro-els-0.crt > opendistro-els-0.pem
      : $ cat opendistro-els-0.crt > opendistro-els-0-key.pem
    - key 파일만 pkcs8 형식으로 변환
      : $ openssl pkcs8 -topk8 -inform PEM -in esnode-k.pem -out esnode-key.pem -nocrypt
      : $ openssl pkcs8 -topk8 -inform PEM -in opendistro-els-0-key.pem -out opendistro-els-0-key-8.pem -nocrypt
    - 최종적으로 쓰는 파일 딱 4개
      : esnode.pem / esnode-key.pem / opendistro-els-0.pem / opendistro-els-0-key-8.pem
  a-2. elasticsearch 의 Certificate 객체 생성 (cert-manager 환경)
    - $ k apply -f 01_es-cert.yaml
  b-1. kibana 의 인증서, 키
    - 인증서, 키 생성
      : ./generateTls.sh -name=tls -dns=opendistro-kibana.kube-logging.svc -dns=opendistro-kibana.kube-logging.svc.cluster.local
  b-2. kibana 의 Certificate 객체 생성 (cert-manager 환경)
    - $ k apply -f 02_kibana-cert.yaml

2. keycloak 설정
  a. tmax realm으로 접속
  b. kibana client 생성 - 사진1,2,3 참조
    - role에서 admin, all_access 줘야 그 계정이 index 접근 가능해짐
  c. kibana의 credentials에서 secret 복사 - kibana.yml에 적어야함
    - 테스트 해보니 public도 됨

3. apply
  a. $ k apply -f 03_es-config.yaml
  b. $ k apply -f 04_opendistro-es.yaml
  c. $ k apply -f 05_opendistro-kibana.yaml

4. 접속
  a. https://{kibanaIP:PORT}/

5. Fluentd 연동
  a. <match fluent.**> 
      user "#{ENV['FLUENT_ELASTICSEARCH_USER']}"
      password "#{ENV['FLUENT_ELASTICSEARCH_PASSWORD']}"
     </match>
  b. - name:  FLUENT_ELASTICSEARCH_USER
        value: "admin"
      - name:  FLUENT_ELASTICSEARCH_PASSWORD
        value: "admin"

6. kibana에서 인덱스 생성
  a. stack management -> index patterns에서 생성
  b. discover에서 조회

7. 권한에 의한 제어
  - $ curl -k -X GET "http://localhost:9200/_opendistro/_security/api/rolesmapping?pretty" -H 'Content-Type: application/json' -u admin:admin
  - 해당 명령어로 조회되는 롤 매핑에서, "{"ROLE_TTT" { ..... "bakend_roles" : [ "XXX", ...] , "users" : [ "YYY" , ... ] , ... }"
  - keycloak에서 XXX라는 이름의 backend_role을 부여하면, 그 keycloak 계정에다가 es에서 정의된 ROLE_TTT를 부여 가능
  - kibana or fluentd는 users에 적힌 YYY로 로그인하면, ROLE_TTT가 부여된다.
  - ROLE_TTT에 접근하는 방법은 위에 두개이다. backend_roles=keycloak에서 주어진 role / users=로그인 계정
  - n:1 매칭 가능
  - ROLE_TTT에는 무슨 권한이 있나는 아래 명령어
    $ curl -k -X GET "http://localhost:9200/_opendistro/_security/api/roles?pretty" -H 'Content-Type: application/json' -u admin:admin
-----
※참고 사이트
- https://nirahhp999.medium.com/opendistro-openid-auth-domain-auth-login-with-keycloak-d4ad2dffb5e9
- https://opendistro.github.io/for-elasticsearch-docs/docs/security/configuration/openid-connect/