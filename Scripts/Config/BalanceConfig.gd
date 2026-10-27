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
