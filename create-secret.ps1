# 🔒 Função para criar Secret do Kubernetes a partir do .env
function Create-SecretFromEnv {
    param(
        [string]$EnvFile = ".env",
        [string]$SecretName = "patocast-secrets"
    )
    
    Write-Host "🔒 Criando Secret '$SecretName' a partir do arquivo '$EnvFile'..." -ForegroundColor Cyan
    
    # Verificar se arquivo .env existe
    if (-not (Test-Path $EnvFile)) {
        Write-Host "❌ Arquivo $EnvFile não encontrado!" -ForegroundColor Red
        Write-Host "📝 Copie .env-exemplo-seguro para .env e configure suas credenciais" -ForegroundColor Yellow
        return $false
    }
    
    # Ler variáveis do .env
    $envVars = @{}
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove aspas se existirem
            $value = $value -replace '^["'']|["'']$', ''
            $envVars[$key] = $value
        }
    }
    
    Write-Host "✅ Lidas $($envVars.Count) variáveis do $EnvFile" -ForegroundColor Green
    
    # Deletar secret existente (se houver)
    kubectl delete secret $SecretName --ignore-not-found=true | Out-Null
    
    # Criar novo secret
    $secretArgs = @("create", "secret", "generic", $SecretName)
    foreach ($key in $envVars.Keys) {
        $secretArgs += "--from-literal=$key=$($envVars[$key])"
    }
    
    $result = & kubectl $secretArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Secret '$SecretName' criado com sucesso!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Erro ao criar secret: $result" -ForegroundColor Red
        return $false
    }
}