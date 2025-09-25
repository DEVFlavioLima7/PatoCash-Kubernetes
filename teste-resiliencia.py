"""
PatoCash Kubernetes Stress Test
Teste de stress inteligente com threads para forçar HPA e monitorar auto-healing

USO BÁSICO:
  python teste-resiliencia.py --test hpa --duration 180

NOVOS PARÂMETROS DE STRESS:
  --http-workers N       Numero de threads gerando requisicoes (default 12)
  --concurrency N        Indicativo de concorrencia alvo (informativo)
  --target-qps N         Tentar aproximar taxa de N requisicoes/segundo
  --aggressive           Multiplica endpoints e remove delays para stress máximo
  --burst N              Quantidade de requisicoes por burst em modo agressivo (default 5)

EXEMPLO PARA FORÇAR HPA RÁPIDO:
  python teste-resiliencia.py --test hpa --duration 300 \
      --http-workers 40 --aggressive --burst 12 --target-qps 800

DICA:
  Ajuste --http-workers + --aggressive + --burst primeiro. Se ainda não atingir CPU alvo,
  adicione --target-qps  (valores iniciais 400, 600, 800...).
"""

import threading
import subprocess
import time
import requests
import json
import sys
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import argparse
import math

class PatoCashStressTester:
    def __init__(self, duration=120, service_url="http://localhost:5000", remote_only=False,
                 http_workers=12, concurrency=200, target_qps=None, aggressive=False, burst=5):
        self.duration = duration
        self.service_url = service_url
        self.remote_only = remote_only
        self.is_running = False
        self.start_time = None
        
        # Contadores de stress
        self.http_requests_count = 0
        self.cpu_stress_active = False
        
        # Estado dos pods (apenas para modo local)
        self.initial_pods = 0
        self.current_pods = 0
        self.max_pods_seen = 0
        self.scaling_detected = False
        
        # Lock para thread safety
        self.lock = threading.Lock()
        
        # Parâmetros adicionais
        self.http_workers = http_workers
        self.concurrency = concurrency  # max simultaneas
        self.target_qps = target_qps    # requisicoes por segundo alvo
        self.aggressive = aggressive
        self.burst = burst
        self._qps_lock = threading.Lock()
        self._requests_window = []  # timestamps recentes
        self._errors = 0
        self._last_qps = 0.0
        
    def run_kubectl(self, command):
        """Executa comando kubectl e retorna resultado"""
        try:
            # Timeout maior para operações de delete
            timeout_val = 30 if 'delete' in command else 15
            result = subprocess.run(
                f"kubectl {command}", 
                shell=True, 
                capture_output=True, 
                text=True, 
                timeout=timeout_val
            )
            return result.stdout.strip(), result.stderr.strip(), result.returncode
        except subprocess.TimeoutExpired:
            return "", "Timeout", 1
        except Exception as e:
            return "", str(e), 1
    
    def get_pod_count(self, app="patocast-backend"):
        """Obtém número atual de pods"""
        stdout, stderr, code = self.run_kubectl(f'get pods -l app={app} --no-headers')
        if code == 0:
            lines = [line for line in stdout.split('\n') if line.strip()]
            running_pods = len([line for line in lines if 'Running' in line])
            return running_pods
        return 0
    
    def get_cpu_usage(self):
        """Obtém uso atual de CPU dos pods"""
        stdout, stderr, code = self.run_kubectl('top pods --no-headers')
        if code == 0:
            backend_pods_cpu = []
            for line in stdout.split('\n'):
                if 'patocast-backend' in line and line.strip():
                    parts = line.split()
                    if len(parts) >= 2:
                        cpu_str = parts[1]  # Formato: '2m' ou '100m'
                        cpu_val = int(cpu_str.replace('m', '')) if 'm' in cpu_str else 0
                        backend_pods_cpu.append(cpu_val)
            return backend_pods_cpu
        return []
    
    def get_hpa_status(self):
        """Obtém status do HPA"""
        stdout, stderr, code = self.run_kubectl('get hpa patocast-backend-hpa --no-headers')
        if code == 0:
            parts = stdout.split()
            if len(parts) >= 6:
                targets = parts[2]  # Formato: 'cpu: 2%/50%'
                replicas = parts[5]
                
                # Extrair porcentagem atual
                cpu_percent = 0
                if 'cpu:' in targets and '/' in targets:
                    try:
                        cpu_part = targets.split('cpu:')[1].split('/')[0].strip()
                        cpu_percent = int(cpu_part.replace('%', ''))
                    except:
                        pass
                
                return cpu_percent, int(replicas)
        return 0, 0
    
    def _throttle(self):
        """Controla a taxa de requisicoes para aproximar target_qps se definido."""
        if not self.target_qps:
            return
        now = time.time()
        with self._qps_lock:
            # remover timestamps mais antigos que 1s
            cutoff = now - 1
            self._requests_window = [t for t in self._requests_window if t > cutoff]
            current_qps = len(self._requests_window)
            self._last_qps = current_qps
            if current_qps >= self.target_qps:
                # dormir proporcional ao excesso
                sleep_time = min(0.01, (current_qps - self.target_qps + 1) / (self.target_qps * 5))
                time.sleep(sleep_time)

    def http_stress_worker(self, worker_id):
        """Worker thread para bombardear HTTP requests"""
        session = requests.Session()
        session.timeout = 2
        
        endpoints = [
            "/health",
            "/",
            "/metrics",
            "/api/users",
            "/api/transactions"
        ]
        # Em modo agressivo adicionar rotas repetidas para aumentar stress no servidor
        if self.aggressive:
            endpoints = endpoints * 4  # multiplicar lista
        
        local_count = 0
        
        print(f"🚀 Worker HTTP {worker_id} iniciado")
        
        while self.is_running:
            for endpoint in endpoints:
                if not self.is_running:
                    break
                    
                try:
                    # Burst de 3 requests por endpoint
                    for _ in range(3 if not self.aggressive else self.burst):
                        if not self.is_running:
                            break
                        if self.target_qps:
                            self._throttle()
                        try:
                            response = session.get(f"{self.service_url}{endpoint}")
                            local_count += 1
                            with self._qps_lock:
                                self._requests_window.append(time.time())
                        except requests.exceptions.RequestException:
                            with self.lock:
                                self._errors += 1
                        except Exception:
                            with self.lock:
                                self._errors += 1
                        # sem delay em modo agressivo; caso normal pequeno yield
                        if not self.aggressive:
                            time.sleep(0.001)
                except Exception:
                    # Protege loop externo de qualquer erro inesperado
                    with self.lock:
                        self._errors += 1
                    continue
        
        with self.lock:
            self.http_requests_count += (local_count % 100)
        
        print(f"💥 Worker HTTP {worker_id} finalizado: ~{local_count} requests")
    
    def cpu_stress_worker(self, pod_name):
        """Worker para stress de CPU direto no pod"""
        print(f"🔥 Iniciando stress CPU no pod: {pod_name}")
        
        # Comando para stress máximo de CPU
        cpu_cmd = f'exec {pod_name} -- sh -c "timeout {self.duration + 10} dd if=/dev/zero of=/dev/null & timeout {self.duration + 10} yes > /dev/null &"'
        
        stdout, stderr, code = self.run_kubectl(cpu_cmd)
        
        if code == 0:
            print(f"✅ Stress CPU ativado no pod: {pod_name}")
            self.cpu_stress_active = True
        else:
            print(f"❌ Falha no stress CPU do pod {pod_name}: {stderr}")
    
    def monitoring_worker(self):
        """Worker para monitoramento contínuo"""
        print("📊 Monitor de HPA iniciado")
        
        last_cpu = 0
        last_replicas = self.initial_pods
        
        while self.is_running:
            try:
                # Obter métricas atuais
                cpu_percent, current_replicas = self.get_hpa_status()
                cpu_usage_list = self.get_cpu_usage()
                current_pods = self.get_pod_count()
                
                # Atualizar estado
                with self.lock:
                    self.current_pods = current_pods
                    if current_pods > self.max_pods_seen:
                        self.max_pods_seen = current_pods
                    
                    if current_pods > self.initial_pods and not self.scaling_detected:
                        self.scaling_detected = True
                        print(f"🚀 SCALING DETECTADO! Pods: {self.initial_pods} → {current_pods}")
                
                # Calcular tempo decorrido
                elapsed = int(time.time() - self.start_time) if self.start_time else 0
                
                # Limpar tela e mostrar status
                subprocess.run("cls", shell=True)  # Windows
                # subprocess.run("cls", shell=True)  # Windows
                
                print(f"{'='*60}")
                print(f"🎯 PATOCASH KUBERNETES STRESS TEST")
                print(f"{'='*60}")
                print(f"⏱️  Tempo: {elapsed}s / {self.duration}s")
                print(f"🔥 HTTP Requests: {self.http_requests_count:,} | Errors: {self._errors}")
                if self.target_qps:
                    print(f"🎯 QPS alvo: {self.target_qps} | Atual ~ {self._last_qps:.1f}")
                print(f"👥 Workers: {self.http_workers} | Aggressive: {self.aggressive} | Burst: {self.burst}")
                print(f"")
                print(f"📊 HPA STATUS:")
                print(f"   CPU Atual: {cpu_percent}% (Target: 50%)")
                print(f"   Pods: {current_pods} (Max visto: {self.max_pods_seen})")
                print(f"   Scaling: {'✅ DETECTADO' if self.scaling_detected else '⏳ Aguardando...'}")
                print(f"")
                
                if cpu_usage_list:
                    print(f"💻 CPU por Pod (milicores):")
                    for i, cpu in enumerate(cpu_usage_list):
                        status = "🔥 ALTO" if cpu > 80 else "📈 SUBINDO" if cpu > 30 else "💤 BAIXO"
                        print(f"   Pod {i+1}: {cpu}m {status}")
                    print(f"")
                
                # Status baseado no progresso
                if cpu_percent > 50:
                    print(f"🚨 CPU MUITO ALTA ({cpu_percent}%) - SCALING IMINENTE!")
                elif cpu_percent > 30:
                    print(f"⚠️  CPU SUBINDO ({cpu_percent}%) - Próximo do threshold")
                elif cpu_percent > 10:
                    print(f"📈 CPU MODERADA ({cpu_percent}%) - Stress funcionando")
                else:
                    print(f"💤 CPU BAIXA ({cpu_percent}%) - Precisa mais stress")
                
                print(f"{'='*60}")
                
                # Alertas especiais
                if self.scaling_detected and elapsed > (self.duration - 15):
                    print(f"✅ SUCESSO! Scaling detectado, finalizando em breve...")
                
                time.sleep(3)  # Update a cada 3 segundos
                
            except Exception as e:
                print(f"❌ Erro no monitoramento: {e}")
                time.sleep(5)
        
        print("📊 Monitoramento finalizado")
    
    def run_stress_test(self):
        """Executa o teste de stress completo"""
        print(f"🎯 INICIANDO PATOCASH STRESS TEST")
        print(f"Duração: {self.duration}s")
        print(f"Service URL: {self.service_url}")
        if self.remote_only:
            print("🌐 Modo REMOTE-ONLY (apenas HTTP)")
        print(f"{'='*50}")
        
        # Verificar estado inicial (apenas em modo local)
        if not self.remote_only:
            self.initial_pods = self.get_pod_count()
            self.max_pods_seen = self.initial_pods
            
            if self.initial_pods == 0:
                print("❌ ERRO: Nenhum pod backend encontrado!")
                return False
            
            print(f"📋 Estado inicial: {self.initial_pods} pods")
        
        # Verificar se serviço está acessível
        try:
            response = requests.get(f"{self.service_url}/health", timeout=5)
            print(f"✅ Serviço acessível: HTTP {response.status_code}")
        except:
            print(f"⚠️  Serviço pode não estar acessível em {self.service_url}")
        
        # Iniciar teste
        self.is_running = True
        self.start_time = time.time()
        
        threads = []
        
        try:
            # 1. Iniciar threads de stress HTTP (12 workers)
            print(f"🚀 Iniciando {self.http_workers} workers HTTP... (concorrência alvo {self.concurrency})")
            for i in range(self.http_workers):
                thread = threading.Thread(target=self.http_stress_worker, args=(i+1,))
                thread.daemon = True
                thread.start()
                threads.append(thread)
            
            # 2. Iniciar stress CPU nos pods (apenas modo local)
            if not self.remote_only:
                print(f"🔥 Iniciando stress CPU nos pods...")
                stdout, stderr, code = self.run_kubectl('get pods -l app=patocast-backend -o jsonpath="{.items[*].metadata.name}"')
                if code == 0:
                    pod_names = stdout.split()
                    for pod_name in pod_names:
                        if pod_name.strip():
                            thread = threading.Thread(target=self.cpu_stress_worker, args=(pod_name,))
                            thread.daemon = True
                            thread.start()
                            threads.append(thread)
            else:
                print(f"🌐 Modo remote-only: Pulando stress CPU nos pods")
            
            # 3. Iniciar monitoramento (apenas modo local)
            if not self.remote_only:
                monitor_thread = threading.Thread(target=self.monitoring_worker)
                monitor_thread.daemon = True
                monitor_thread.start()
                threads.append(monitor_thread)
            else:
                print(f"🌐 Modo remote-only: Pulando monitoramento de pods")
            
            # 4. Aguardar duração do teste
            time.sleep(self.duration)
            
        except KeyboardInterrupt:
            print(f"\n🛑 Teste interrompido pelo usuário")
        
        finally:
            # Finalizar teste
            print(f"\n⏹️  Finalizando teste...")
            self.is_running = False
            
            # Aguardar threads finalizarem (max 10s)
            for thread in threads:
                thread.join(timeout=2)
            
            # Relatório final
            self.generate_final_report()
        
        # Em modo remote-only, sucesso é baseado apenas em completar as requisições
        if self.remote_only:
            return self.http_requests_count > 0
        else:
            return self.scaling_detected
    
    def generate_final_report(self):
        """Gera relatório final do teste"""
        print(f"\n{'='*60}")
        print(f"📋 RELATÓRIO FINAL DO TESTE")
        print(f"{'='*60}")
        
        print(f"⏱️  Duração total: {self.duration}s")
        print(f"🔥 HTTP Requests enviadas: {self.http_requests_count:,} | Errors: {self._errors}")
        if self.target_qps:
            print(f"🎯 QPS Alvo: {self.target_qps} | Último QPS medido ~ {self._last_qps:.1f}")
        
        if not self.remote_only:
            final_cpu, final_replicas = self.get_hpa_status()
            final_pods = self.get_pod_count()
            
            print(f"📊 Pods inicial → final: {self.initial_pods} → {final_pods}")
            print(f"📈 Máximo de pods visto: {self.max_pods_seen}")
            print(f"⚡ CPU final: {final_cpu}%")
            
            if self.scaling_detected:
                print(f"✅ RESULTADO: SUCESSO - HPA funcionou!")
                print(f"   Scaling automático detectado durante o teste")
            else:
                print(f"❌ RESULTADO: Scaling não detectado")
                print(f"   Pode precisar de mais stress ou mais tempo")
        else:
            if self.http_requests_count > 0:
                print(f"✅ Modo remote-only: Teste HTTP concluído com sucesso")
                print(f"   {self.http_requests_count:,} requisições enviadas")
            else:
                print(f"❌ Modo remote-only: Nenhuma requisição HTTP completada")
            print(f"💡 Para verificar scaling, execute o teste localmente com kubectl")
        
        print(f"{'='*60}")

def test_remote_pod_deletion():
    """Demonstra como excluir pod remotamente"""
    print(f"🌐 COMO EXCLUIR POD REMOTAMENTE")
    print(f"{'='*70}")
    print(f"")
    
    # Mostrar pods atuais como exemplo
    tester = PatoCashStressTester()
    stdout, stderr, code = tester.run_kubectl('get pods -l app=patocast-backend --no-headers')
    if code == 0 and stdout.strip():
        pod_lines = [line for line in stdout.split('\n') if line.strip()]
        if pod_lines:
            example_pod = pod_lines[0].split()[0]
            print(f"📋 EXEMPLO com pod atual: {example_pod}")
            print(f"")
    
    print(f"🔍 COMO DESCOBRIR O NOME DO POD:")
    print(f"   kubectl get pods -l app=patocast-backend")
    print(f"   # Copia o nome de qualquer pod da lista")
    print(f"")
    print(f"📋 MÉTODOS DE ACESSO REMOTO:")
    print(f"")
    print(f"1️⃣  VIA SSH (MAIS FÁCIL):")
    print(f"   🔧 COMO HABILITAR SSH NO SEU PC:")
    print(f"      Windows: Configurações → Apps → Recursos Opcionais → OpenSSH Server")
    print(f"      Ou via PowerShell (Admin): Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0")
    print(f"      Iniciar: net start sshd")
    print(f"   📝 CONECTAR DO OUTRO PC:")
    print(f"      ssh {os.environ.get('USERNAME', 'seu_usuario')}@192.168.1.100")
    print(f"   🏃 DEPOIS DE CONECTAR:")
    print(f"      kubectl delete pod <nome-do-pod>")
    print(f"   💡 Exemplo: kubectl delete pod {example_pod if 'example_pod' in locals() else 'patocast-backend-xxx-yyy'}")
    print(f"")
    print(f"2️⃣  VIA KUBECTL REMOTO:")
    print(f"   🔧 Pré-requisito: kubeconfig configurado ou certificados")
    print(f"   📝 Comando direto:")
    print(f"      kubectl --server=https://192.168.1.100:6443 \\")
    print(f"              --insecure-skip-tls-verify \\")
    print(f"              delete pod <nome-do-pod>")
    print(f"")
    print(f"3️⃣  VIA KUBECTL PROXY (RECOMENDADO PARA TESTES):")
    print(f"   🖥️  No servidor (192.168.1.100):")
    print(f"      kubectl proxy --address=0.0.0.0 --port=8080")
    print(f"   💻 Do seu computador:")
    print(f"      curl -X DELETE http://192.168.1.100:8080/api/v1/namespaces/default/pods/<nome-do-pod>")
    print(f"")
    print(f"4️⃣  VIA DASHBOARD WEB (SE DISPONÍVEL):")
    print(f"   🌐 Acesse: http://192.168.1.100:30080 (se dashboard estiver rodando)")
    print(f"   👆 Clique em Pods → Selecionar pod → Delete")
    print(f"")
    print(f"⚡ CONFIGURAÇÃO RÁPIDA SSH (Windows):")
    print(f"   1. PowerShell como Admin:")
    print(f"      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0")
    print(f"      Start-Service sshd")
    print(f"      Set-Service -Name sshd -StartupType 'Automatic'")
    print(f"   2. Do outro PC: ssh {os.environ.get('USERNAME', 'usuario')}@192.168.1.100")
    print(f"")
    print(f"🔥 MÉTODO MAIS RÁPIDO PARA TESTAR:")
    print(f"   1. Execute: python teste-resiliencia.py --test=auto-healing")
    print(f"   2. O script mostra o nome do pod que será excluído")
    print(f"   3. Copie o comando mostrado e execute remotamente")
    print(f"")
    print(f"🛡️  SEGURANÇA: SSH é o método mais seguro para produção")
    print(f"{'='*70}")

def test_auto_healing():
    """Teste de auto-healing (deletar pod)"""
    print(f"🔄 TESTE DE AUTO-HEALING")
    print(f"{'='*40}")
    
    tester = PatoCashStressTester()
    
    # Obter todos os pods e mostrar opções
    stdout, stderr, code = tester.run_kubectl('get pods -l app=patocast-backend --no-headers')
    if code != 0 or not stdout.strip():
        print("❌ ERRO: Nenhum pod backend encontrado!")
        return False
    
    # Listar todos os pods disponíveis
    pod_lines = [line for line in stdout.split('\n') if line.strip() and 'Running' in line]
    if not pod_lines:
        print("❌ ERRO: Nenhum pod Running encontrado!")
        return False
    
    print(f"📋 Pods disponíveis para exclusão:")
    for i, line in enumerate(pod_lines):
        pod_name = line.split()[0]
        status = line.split()[2]
        print(f"   {i+1}. {pod_name} ({status})")
    
    # Selecionar o primeiro pod automaticamente
    pod_to_delete = pod_lines[0].split()[0]
    initial_pods = tester.get_pod_count()
    
    print(f"")
    print(f"� Total de pods: {initial_pods}")
    print(f"🎯 Pod selecionado para exclusão: {pod_to_delete}")
    print(f"📍 DICA: Para excluir remotamente, use:")
    print(f"   kubectl delete pod {pod_to_delete}")
    print(f"⏳ Deletando em 3 segundos...")
    time.sleep(3)
    
    # Deletar pod
    start_time = time.time()
    print(f"💥 DELETANDO POD: {pod_to_delete}")
    stdout, stderr, code = tester.run_kubectl(f'delete pod {pod_to_delete} --grace-period=0 --force')
    
    if code != 0:
        print(f"❌ ERRO ao deletar pod: {stderr}")
        # Tentar delete normal se o force falhar
        print(f"🔄 Tentando delete normal...")
        stdout, stderr, code = tester.run_kubectl(f'delete pod {pod_to_delete}')
        if code != 0:
            print(f"❌ ERRO no delete normal: {stderr}")
            return False
    
    # Monitorar recuperação
    print(f"📊 Monitorando auto-healing...")
    healed = False
    new_pod_name = None
    
    # Aguardar um pouco após deleção para capturar estado real
    time.sleep(1)
    
    for attempt in range(30):  # 30 tentativas = ~1 minuto
        current_pods = tester.get_pod_count()
        elapsed = int(time.time() - start_time)
        
        # Obter nomes atuais dos pods
        stdout, stderr, code = tester.run_kubectl('get pods -l app=patocast-backend -o jsonpath="{.items[*].metadata.name}"')
        current_pod_names = set(stdout.split()) if code == 0 else set()
        
        # Na primeira iteração, mostrar estado atual
        if attempt == 0:
            print(f"🔍 Pods restantes após deleção: {list(current_pod_names)}")
        
        # Identificar novo pod
        if current_pods >= initial_pods and not new_pod_name:
            # Procurar por pods que não existiam na lista inicial
            if attempt > 1:  # Dar tempo para o pod aparecer
                for pod_name in current_pod_names:
                    if pod_name != pod_to_delete and not new_pod_name:
                        # Verificar se é um pod novo (diferente do deletado)
                        stdout_age, _, _ = tester.run_kubectl(f'get pod {pod_name} -o jsonpath="{{.metadata.creationTimestamp}}"')
                        if stdout_age and not new_pod_name:
                            new_pod_name = pod_name
                            print(f"🆕 NOVO POD DETECTADO: {new_pod_name}")
                            break
        
        print(f"[{attempt+1}/30] Tempo: {elapsed}s | Pods Running: {current_pods}")
        
        if current_pods >= initial_pods:
            healed = True
            total_time = int(time.time() - start_time)
            
            # Mostrar resultado final
            final_stdout, _, _ = tester.run_kubectl('get pods -l app=patocast-backend --no-headers')
            if final_stdout:
                print(f"📋 Estado final dos pods:")
                for line in final_stdout.split('\n'):
                    if line.strip():
                        parts = line.split()
                        pod_name = parts[0]
                        age = parts[4] if len(parts) > 4 else "?"
                        is_new = "🆕 NOVO" if pod_name != pod_to_delete and "s" in age else ""
                        print(f"   {pod_name} (Age: {age}) {is_new}")
            
            print(f"✅ SUCESSO: Auto-healing em {total_time}s!")
            break
        
        time.sleep(2)
    
    if not healed:
        print(f"❌ TIMEOUT: Auto-healing não completou em 60s")
    
    return healed

def main():
    parser = argparse.ArgumentParser(description='PatoCash Kubernetes Stress Tester')
    parser.add_argument('--test', choices=['hpa', 'auto-healing', 'all', 'remote-help', 'list-pods'], default='all', help='Tipo de teste')
    parser.add_argument('--duration', type=int, default=120, help='Duração do stress test em segundos')
    parser.add_argument('--url', default='http://localhost:5000',help='URL do serviço PatoCash')
    parser.add_argument('--remote-only', action='store_true', help='Apenas envia requisições HTTP (não acessa kubectl/pods)')
    parser.add_argument('--http-workers', type=int, default=12, help='Quantidade de threads de HTTP workers')
    parser.add_argument('--concurrency', type=int, default=200, help='Concorrência alvo (ajuste indicativo)')
    parser.add_argument('--target-qps', type=int, help='Taxa alvo de requisições por segundo')
    parser.add_argument('--aggressive', action='store_true', help='Modo agressivo (mais endpoints e sem delays)')
    parser.add_argument('--burst', type=int, default=5, help='Quantidade de requests por burst em modo agressivo')
    args = parser.parse_args()
    
    if args.test == 'remote-help':
        test_remote_pod_deletion()
        success = True
    elif args.test == 'list-pods':
        if args.remote_only:
            print("⚠️  --remote-only não suporta listar pods (requer kubectl)")
            success = False
        else:
            tester = PatoCashStressTester()
            stdout, stderr, code = tester.run_kubectl('get pods -l app=patocast-backend')
            if code == 0:
                print("📋 PODS DISPONÍVEIS PARA EXCLUSÃO:")
                print(stdout)
                print("\n💡 Para excluir remotamente, copie um nome e use:")
                print("   kubectl delete pod <nome-do-pod>")
            else:
                print("❌ Erro ao listar pods")
            success = True
    elif args.test == 'auto-healing':
        if args.remote_only:
            print("⚠️  --remote-only não suporta teste auto-healing (requer kubectl)")
            success = False
        else:
            success = test_auto_healing()
    elif args.test == 'hpa':
        tester = PatoCashStressTester(duration=args.duration, service_url=args.url, remote_only=args.remote_only,
                                      http_workers=args.http_workers, concurrency=args.concurrency,
                                      target_qps=args.target_qps, aggressive=args.aggressive, burst=args.burst)
        success = tester.run_stress_test()
    elif args.test == 'all':
        if args.remote_only:
            print("🌐 MODO REMOTE-ONLY: Executando apenas teste HPA HTTP")
            print("="*50)
            tester = PatoCashStressTester(duration=args.duration, service_url=args.url, remote_only=args.remote_only)
            success = tester.run_stress_test()
        else:
            print("🚀 EXECUTANDO TODOS OS TESTES")
            print("="*50)
            
            healing_success = test_auto_healing()
            print("\n⏳ Aguardando 10s antes do próximo teste...")
            time.sleep(10)
            
            tester = PatoCashStressTester(duration=args.duration, service_url=args.url, remote_only=args.remote_only,
                                          http_workers=args.http_workers, concurrency=args.concurrency,
                                          target_qps=args.target_qps, aggressive=args.aggressive, burst=args.burst)
            hpa_success = tester.run_stress_test()
            
            success = healing_success and hpa_success
    
    print(f"\n🎯 TESTE CONCLUÍDO: {'✅ SUCESSO' if success else '❌ FALHA'}")
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()