all:
	@docker-compose --file 'docker-compose.yml' --project-name 'web-i-tela_home-html' down 
	@docker-compose up --build

back:
	@docker-compose up -d postgres
	@cd backend && pip install -r requirements.txt
	@cd backend && python app.py

frontend:
	@cd front && npm install && npm start

create_kubernetes:
	minikube delete
	minikube start --cpus=2 --memory=4096 --driver=docker
	minikube addons enable metrics-server
	kubectl get nodes

create_docker:
	minikube docker-env | Invoke-Expression
	docker build -t patocast-backend:latest ./backend
	docker build -t patocast-frontend:latest ./front
	Wait-Job *
	docker images | Select-String patocast

apply_pods:
	kubectl apply -f k8s-backend.yaml
	kubectl apply -f k8s-frontend.yaml
	kubectl wait --for=condition=ready pod -l app=patocast-backend --timeout=120s
	kubectl wait --for=condition=ready pod -l app=patocast-frontend --timeout=120s
	kubectl apply -f k8s-hpa.yaml
	kubectl get all

run_front:
	kubectl port-forward service/patocast-frontend-service 3000:3000

test_pods:
	kubectl get pods
	kubectl get hpa
	kubectl delete pod $(kubectl get pods -l app=patocast-backend -o jsonpath='{.items[0].metadata.name}')
	kubectl get pods -l app=patocast-backend
	kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://patocast-backend-service:5000/ || true; done"
	for ($i=1; $i -le 4; $i++) {
		Write-Host "=== Minuto $i ==="
		kubectl get hpa
		kubectl top pods
		Start-Sleep -Seconds 30
	}
