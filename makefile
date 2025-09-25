all:
	@docker-compose --file 'docker-compose.yml' --project-name 'web-i-tela_home-html' down 
	@docker-compose up --build

back:
	@docker-compose up -d postgres
	@cd backend && pip install -r requirements.txt
	@cd backend && python app.py

frontend:
	@cd front && npm install && npm start

run_monitoring:
	@cd maquina2-monitoring && powershell -ExecutionPolicy Bypass -File setup.ps1

run_test:
	python teste-resiliencia.py