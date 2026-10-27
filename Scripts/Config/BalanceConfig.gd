extends Resource
class_name BalanceConfig
##
# Todos os números de balanceamento do MVP, num lugar só.
# Edite o arquivo res://Config/balanceamento.tres no Inspector.
# Listas com 3 valores seguem a intensidade do evento: [baixa, média, alta].
##

@export_group("Rodada")
@export var dias_por_rodada: int = 7
## Dinheiro no início do jogo (também é o orçamento usado na nota de finanças)
@export var orcamento_rodada: int = 20000
@export var popularidade_inicial: float = 50.0
## Nota mínima (0 a 100) para receber a proposta de anexação
@export var nota_minima: float = 60.0

@export_group("Viaturas e custos")
## Viaturas de cada sede no começo
@export var viaturas_por_sede: int = 2
## Custo fixo de cada viatura enviada
@export var custo_por_viatura: int = 400
## Custo por km de trajeto (sede mais longe = envio mais caro)
@export var custo_por_km: int = 30

@export_group("Sedes")
## Custo para construir uma sede (já vem com as viaturas iniciais)
@export var custo_sede: int = 6000
## Vagas para sedes por subprefeitura, por dificuldade [Fácil, Normal, Difícil]
@export var vagas_por_dificuldade: Array[int] = [8, 10, 12]
## Máximo de sedes do mesmo órgão numa subprefeitura
@export var max_sedes_por_orgao: int = 2

@export_group("Upgrades da sede (em ordem: 1, 2, 3)")
## Custo de cada upgrade [Frota rápida, Equipe treinada, Ampliação]
@export var custo_upgrade: Array[int] = [3000, 4000, 5000]
## Upgrade 1: viaturas da sede mais rápidas (0.25 = 25%)
@export var bonus_velocidade: float = 0.25
## Upgrade 2: atendimentos mais rápidos (0.25 = 25%)
@export var bonus_resolucao: float = 0.25
## Upgrade 3: viaturas a mais na sede
@export var viaturas_ampliacao: int = 2

@export_group("Economia semanal")
## Arrecadação por subprefeitura sob o seu comando, no fim de cada semana
@export var arrecadacao_por_subprefeitura: int = 15000
@export var manutencao_por_sede: int = 500
@export var manutencao_por_viatura: int = 200

@export_group("Geração da semana")
## Eventos na 1ª semana com uma subprefeitura
@export var eventos_semana_base: int = 6
## Eventos a mais por subprefeitura além da primeira
@export var eventos_por_subprefeitura_extra: int = 2
@export var eventos_semana_min: int = 3
@export var eventos_semana_max: int = 12
## Máximo de eventos num mesmo dia
@export var eventos_por_dia_max: int = 3
## Quanto um evento fica mais provável no clima "dele" (ex.: enchente na chuva)
@export var peso_clima_favoravel: float = 3.0
## Chance de cada clima [Sol, Calor, Nublado, Chuva, Temporal]
@export var chance_clima: Array[float] = [0.3, 0.2, 0.2, 0.2, 0.1]
## Peso de cada clima na distribuição dos eventos pelos dias [Sol, Calor, Nublado, Chuva, Temporal]
@export var peso_dia_por_clima: Array[float] = [1.0, 1.2, 0.8, 1.3, 2.0]

@export_group("Dificuldade pela população")
## A partir de quantos habitantes a subprefeitura é Normal
@export var populacao_normal: int = 400000
## A partir de quantos habitantes a subprefeitura é Difícil
@export var populacao_dificil: int = 700000

@export_group("Popularidade")
@export var pop_resolver: Array[float] = [1.0, 2.0, 4.0]
@export var pop_escalar: Array[float] = [-1.0, -3.0, 0.0]
@export var pop_falhar: Array[float] = [0.0, -4.0, -8.0]
@export var pop_por_morte: float = -1.0
## Tirar uma viatura de uma ocorrência em aberto (voltar para a sede ou redirecionar)
@export var pop_cancelar: Array[float] = [-1.0, -2.0, -4.0]

@export_group("Mortes quando o evento falha")
@export var mortes_min: Array[int] = [0, 0, 3]
@export var mortes_max: Array[int] = [0, 2, 8]

@export_group("Nota de aproveitamento")
@export var peso_atendimento: float = 0.40
@export var peso_mortes: float = 0.25
@export var peso_financas: float = 0.15
@export var peso_popularidade: float = 0.20
## Com essa quantidade de mortes a nota de mortes chega a 0
@export var mortes_para_zerar: int = 10
## Gastar essa fração acima do orçamento zera a nota de finanças (0.5 = 50% acima)
@export var estouro_para_zerar: float = 0.5
## Variação de popularidade (para mais ou para menos) que leva a nota a 100 ou a 0
@export var variacao_pop_extrema: float = 10.0
## Quanto vale uma demanda resolvida depois de escalar (resolvida a tempo = 100)
@export var valor_resolvida_apos_escalar: float = 50.0
