extends Node

enum UnitType
{
	COMLURB,
	CET,
	SAMU,
	DEFESA_CIVIL,
	GUARDA_MUNICIPAL,
	BOMBEIROS
}

var UnitDict = { 
	UnitType.COMLURB: "Comlurb",
	UnitType.CET: 'CET',
	UnitType.SAMU: 'SAMU',
	UnitType.DEFESA_CIVIL: 'Defesa Civil',
	UnitType.GUARDA_MUNICIPAL: 'Guarda Municipal',
	UnitType.BOMBEIROS: 'Bombeiros'
}

enum EventState
{
	ATIVO,
	EM_ATENDIMENTO,
	RESOLVIDO,
	EXPIRADO,
	ESCALADO
}

# Características de uma subprefeitura. Um evento com etiquetas só surge
# em subprefeituras que tenham pelo menos uma delas.
enum Etiqueta
{
	PRAIA,
	ENCOSTA,
	MATA,
	ALAGAMENTO,
	COMERCIO,
	CARNAVAL
}

var EtiquetaDict = {
	Etiqueta.PRAIA: 'Praia',
	Etiqueta.ENCOSTA: 'Encosta',
	Etiqueta.MATA: 'Mata',
	Etiqueta.ALAGAMENTO: 'Alagamento',
	Etiqueta.COMERCIO: 'Comércio',
	Etiqueta.CARNAVAL: 'Carnaval'
}

enum Clima
{
	SOL,
	CALOR,
	NUBLADO,
	CHUVA,
	TEMPORAL
}

var ClimaDict = {
	Clima.SOL: 'Sol',
	Clima.CALOR: 'Calor forte',
	Clima.NUBLADO: 'Nublado',
	Clima.CHUVA: 'Chuva',
	Clima.TEMPORAL: 'Temporal'
}

# Dificuldade de um evento: vem da população da subprefeitura onde ele surge
enum Dificuldade
{
	FACIL,
	NORMAL,
	DIFICIL
}

var DificuldadeDict = {
	Dificuldade.FACIL: 'Fácil',
	Dificuldade.NORMAL: 'Normal',
	Dificuldade.DIFICIL: 'Difícil'
}
