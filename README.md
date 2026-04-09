# Pipeline Medical — CI/CD avec Terraform + GitHub Actions

## Architecture

```
push sur main
    │
    ▼
┌─────────────────────────────┐
│  Job 1 — Terraform          │
│  Crée la VM EC2 Ubuntu 24   │
│  + Elastic IP + Sec. Group  │
└──────────────┬──────────────┘
               │ IP publique
               ▼
┌─────────────────────────────┐
│  Job 2 — Setup & Deploy     │
│  SSH → VM                   │
│  - Installe prérequis       │
│  - Télécharge le projet     │
│  - Configure MySQL          │
│  - Importe les bases SQL    │
│  - Migrations Django        │
│  - npm install              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Job 3 — Run & URLs         │
│  - Démarre backend:8000     │
│  - Démarre frontend:5173    │
│  - Affiche les URLs         │
└─────────────────────────────┘
```

## Secrets GitHub requis

Dans **Settings → Secrets and variables → Actions**, ajouter :

| Secret               | Description                          |
|----------------------|--------------------------------------|
| `AWS_ACCESS_KEY_ID`     | Clé d'accès AWS                      |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS                      |
| `AWS_SESSION_TOKEN`     | Token de session AWS (si applicable) |
| `SSH_PRIVATE_KEY`       | Contenu du fichier `vockey.pem`      |

## Utilisation

### Déployer
Chaque `git push` sur `main` déclenche automatiquement le pipeline.

### Détruire
Aller dans **Actions → Destroy Infrastructure → Run workflow** et taper `destroy` pour confirmer.

## Structure du repo

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml      # Pipeline principal (3 jobs)
│       └── destroy.yml     # Destruction manuelle
├── scripts/
│   └── setup.sh            # Script d'installation EC2
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── terraform.tfvars
├── .gitignore
└── README.md
```
<<<<<<< HEAD
## lancer le back
python manage.py runserver 0.0.0.0:8000

## lancer le front


=======
>>>>>>> 64e7dafc1f15977796f8690dc753f7305ad523c5
