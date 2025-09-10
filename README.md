# Hacka Token Sport – Chiliz Spicy Testnet NFT Ticketing DApp

Este projeto implementa um sistema de venda de ingressos NFT na **Chiliz Spicy Testnet**, usando **Solidity** para o smart contract e **Flutter Web** para o frontend. A integração com o MetaMask permite que usuários comprem ingressos diretamente de seus navegadores.

---

## Visão Geral

1. **Smart Contract (Solidity / Neon EVM ou Ethereum-compatible)**
   - Gerencia dados do evento e vendas  
   - Lógica de compra (`buyTicket`), estatísticas (`getSaleStats`) e fallback seguro  
   - Deploy na Chiliz Spicy Testnet  

2. **Backend RPC (Chiliz RPC API)**
   - Acesso via HTTP JSON-RPC  
   - Chamada de seletores de função para obter dados de evento e vendas  
   - Decodificação manual de `uint256` para estatísticas  

3. **Frontend (Flutter Web)**
   - UI responsiva: exibe informações do evento, estatísticas e saldo do usuário  
   - Conexão e autenticação via MetaMask  
   - Construção, assinatura e envio de transações  

4. **Fluxo de Usuário**
   - Conecta MetaMask → busca dados do evento → exibe estatísticas  
   - Usuário clica em **"Comprar ingresso"** → confirma no MetaMask → vê popup de sucesso  

---

## Estrutura do Repositório

chiliz_ticket_dapp/
├── contracts/
│ └── HackaTokenSport.sol # Smart contract Solidity
├── lib/
│ ├── main.dart # Entrada Flutter
│ ├── services/
│ │ └── web3_service.dart # Lógica de conexão e transações
│ ├── screens/
│ │ ├── home_screen.dart # Tela principal
│ │ └── my_tickets_screen.dart # Tela de ingressos do usuário
│ └── utils/
│ └── constants.dart # Configurações e utilitários
├── web/
│ └── index.html # Bridge JS e scripts MetaMask
├── pubspec.yaml # Dependências Flutter
├── package.json # Config para Hardhat/Neon EVM
└── README.md # Documentação deste projeto

text

---

## Setup e Execução

### 1. Smart Contract

Instalar Hardhat e dependências
npm install

Compilar
npx hardhat compile

Deploy na Neon EVM (Chiliz Spicy Testnet compatível EVM)
npx hardhat run scripts/deploy.js --network spicy

text

### 2. Frontend Flutter

flutter pub get
flutter run -d chrome

text

---

## Principais Tecnologias

- **Solidity / Neon EVM** – Smart contract compatível EVM  
- **Chiliz Spicy Testnet** – Rede de teste EVM  
- **Flutter Web** – Frontend cross-platform responsivo  
- **MetaMask** – Autenticação e assinatura de transações  
- **HTTP JSON-RPC** – Chamadas diretas ao nó Chiliz  

---

## Funcionalidades

- Exibição de informações do evento (nome, local, preço, total de ingressos)  
- Compras de ingressos NFT com pagamento em CHZ  
- Estatísticas de vendas em tempo real (vendidos, disponíveis, status)  
- Visualização de transações recentes e saldo do usuário  
- Fallback seguro em caso de erro de opcode ou execução revertida  

## Capturas de Tela

![Run](./print/print (1).png)  
*Tela.*

![Run](./print/print (2).png)  
*Tela.*

![Run](./print/print (3).png)  
*Tela.*

![Run](./print/print (4).png)  
*Tela.*

![Run](./print/print (5).png)  
*Tela.*

![Run](./print/print (6).png)  
*Tela.*

![Run](./print/print (7).png)  
*Tela.*

---
