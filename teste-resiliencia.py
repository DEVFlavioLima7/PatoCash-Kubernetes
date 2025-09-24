"""
PatoCash Kubernetes Stress Test
Teste de stress inteligente com threads para forçar HPA e monitorar auto-healing
"""

import threading
import subprocess
import time
import requests
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import argparse

class PatoCashStressTester:
    def __init__(self, duration=45, service_url="http://localhost:5000"):
        self.duration = duration
        self.service_url = service_url
        self.is_running = False
        self.start_time = None
        
        # Contadores de stress
        self.http_requests_count = 0
        self.cpu_stress_active = False
        
        # Estado dos pods
        self.initial_pods = 0
        self.current_pods = 0
        self.max_pods_seen = 0
        self.scaling_detected = False
        
        # Lock para thread safety
        self.lock = threading.Lock()
        
    def run_kubectl(self, command):
        """Executa comando kubectl e retorna resultado"""
        try:
            result = subprocess.run(
                f"kubectl {command}", 
                shell=True, 
                capture_output=True, 
                text=True, 
                timeout=10
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
        
        local_count = 0
        
        print(f"🚀 Worker HTTP {worker_id} iniciado")
        
        while self.is_running:
            for endpoint in endpoints:
                if not self.is_running:
                    break
                    
                try:
                    # Burst de 3 requests por endpoint
                    for _ in range(3):
                        response = session.get(f"{self.service_url}{endpoint}")
                        local_count += 1
                        
                        if local_count % 100 == 0:
                            with self.lock:
                                self.http_requests_count += 100
                
                except requests.exceptions.RequestException:
                    # Ignorar erros de rede e continuar bombardeando
                    pass
                except Exception:
                    pass
        
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
                subprocess.run("clear", shell=True)  # Linux/Mac
                # subprocess.run("cls", shell=True)  # Windows
                
                print(f"{'='*60}")
                print(f"🎯 PATOCASH KUBERNETES STRESS TEST")
                print(f"{'='*60}")
                print(f"⏱️  Tempo: {elapsed}s / {self.duration}s")
                print(f"🔥 HTTP Requests: {self.http_requests_count:,}")
                print(f"⚡ CPU Stress: {'ATIVO' if self.cpu_stress_active else 'INATIVO'}")
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
        print(f"{'='*50}")
        
        # Verificar estado inicial
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
            print(f"🚀 Iniciando 12 workers HTTP...")
            for i in range(12):
                thread = threading.Thread(target=self.http_stress_worker, args=(i+1,))
                thread.daemon = True
                thread.start()
                threads.append(thread)
            
            # 2. Iniciar stress CPU nos pods
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
            
            # 3. Iniciar monitoramento
            monitor_thread = threading.Thread(target=self.monitoring_worker)
            monitor_thread.daemon = True
            monitor_thread.start()
            threads.append(monitor_thread)
            
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
        
        return self.scaling_detected
    
    def generate_final_report(self):
        """Gera relatório final do teste"""
        print(f"\n{'='*60}")
        print(f"📋 RELATÓRIO FINAL DO TESTE")
        print(f"{'='*60}")
        
        final_cpu, final_replicas = self.get_hpa_status()
        final_pods = self.get_pod_count()
        
        print(f"⏱️  Duração total: {self.duration}s")
        print(f"🔥 HTTP Requests enviadas: {self.http_requests_count:,}")
        print(f"📊 Pods inicial → final: {self.initial_pods} → {final_pods}")
        print(f"📈 Máximo de pods visto: {self.max_pods_seen}")
        print(f"⚡ CPU final: {final_cpu}%")
        
        if self.scaling_detected:
            print(f"✅ RESULTADO: SUCESSO - HPA funcionou!")
            print(f"   Scaling automático detectado durante o teste")
        else:
            print(f"❌ RESULTADO: Scaling não detectado")
            print(f"   Pode precisar de mais stress ou mais tempo")
        
        print(f"{'='*60}")

def test_auto_healing():
    """Teste de auto-healing (deletar pod)"""
    print(f"🔄 TESTE DE AUTO-HEALING")
    print(f"{'='*40}")
    
    tester = PatoCashStressTester()
    
    # Obter pods atuais
    stdout, stderr, code = tester.run_kubectl('get pods -l app=patocast-backend -o jsonpath="{.items[0].metadata.name}"')
    if code != 0 or not stdout.strip():
        print("❌ ERRO: Nenhum pod backend encontrado!")
        return False
    
    pod_to_delete = stdout.strip()
    initial_pods = tester.get_pod_count()
    
    print(f"📋 Pods iniciais: {initial_pods}")
    print(f"🎯 Pod a deletar: {pod_to_delete}")
    print(f"⏳ Deletando em 3 segundos...")
    time.sleep(3)
    
    # Deletar pod
    start_time = time.time()
    print(f"💥 DELETANDO POD: {pod_to_delete}")
    stdout, stderr, code = tester.run_kubectl(f'delete pod {pod_to_delete}')
    
    if code != 0:
        print(f"❌ ERRO ao deletar pod: {stderr}")
        return False
    
    # Monitorar recuperação
    print(f"📊 Monitorando auto-healing...")
    healed = False
    
    for attempt in range(30):  # 30 tentativas = ~1 minuto
        current_pods = tester.get_pod_count()
        elapsed = int(time.time() - start_time)
        
        print(f"[{attempt+1}/30] Tempo: {elapsed}s | Pods Running: {current_pods}")
        
        if current_pods >= initial_pods:
            healed = True
            total_time = int(time.time() - start_time)
            print(f"✅ SUCESSO: Auto-healing em {total_time}s!")
            break
        
        time.sleep(2)
    
    if not healed:
        print(f"❌ TIMEOUT: Auto-healing não completou em 60s")
    
    return healed

def main():
    parser = argparse.ArgumentParser(description='PatoCash Kubernetes Stress Tester')
    parser.add_argument('--test', choices=['hpa', 'auto-healing', 'all'], default='hpa', help='Tipo de teste')
    parser.add_argument('--duration', type=int, default=45, help='Duração do stress test em segundos')
    parser.add_argument('--url', default='http://localhost:5000',help='URL do serviço PatoCash')
    args = parser.parse_args()
    
    if args.test == 'auto-healing':
        success = test_auto_healing()
    elif args.test == 'hpa':
        tester = PatoCashStressTester(duration=args.duration, service_url=args.url)
        success = tester.run_stress_test()
    elif args.test == 'all':
        print("🚀 EXECUTANDO TODOS OS TESTES")
        print("="*50)
        
        healing_success = test_auto_healing()
        print("\n⏳ Aguardando 10s antes do próximo teste...")
        time.sleep(10)
        
        tester = PatoCashStressTester(duration=args.duration, service_url=args.url)
        hpa_success = tester.run_stress_test()
        
        success = healing_success and hpa_success
    
    print(f"\n🎯 TESTE CONCLUÍDO: {'✅ SUCESSO' if success else '❌ FALHA'}")
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()