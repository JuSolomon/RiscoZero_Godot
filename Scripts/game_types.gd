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
	UnitType.CET: 'Cet',
	UnitType.SAMU: 'Samu',
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

enum ZonaType
{
	CENTRO,
	ZONA_NORTE,
	ZONA_SUL
}
