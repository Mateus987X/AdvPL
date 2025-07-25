//Esta fun��o automatiza o processo de baixa de notas de cr�dito (NCC) 
//no sistema Protheus (TOTVS) quando h� devolu��es de mercadorias. Ela verifica e registra 
//as NCCs vinculadas a notas fiscais de entrada. 


#include 'protheus.ch'
#include 'parmtype.ch'
#Include "Rwmake.ch"  
#Include "Colors.ch" 

user function VFIN015()
	
Local aAreaOld   := GetArea()
Local aAreaSF2   := SF2->(GetArea())
Local lProcessa  := .T.               

Private cPrefixo := Alltrim(GetMv("MV_ZPRENCC"))
Private cTipo    := "NCC"     
Private cNumero	 := Alltrim(SE1->E1_NUM)
Private cParcela := CriaVar("E1_PARCELA",.F.)
Private cNaturez := CriaVar("E1_NATUREZ",.F.)  
Private nSaldNCC := 0      
Private cPrefSe1 := Alltrim(SE1->E1_PREFIXO)
Private cCliSe1  := Alltrim(SE1->E1_CLIENTE)
Private cLojSe1  := Alltrim(SE1->E1_LOJA)        
Private nNValor  := 0
private cCliVend := ""


/////////////////////////////////  
// Verifico o Status do T�tulo //
/////////////////////////////////
DO CASE
	Case !empty(SE1->E1_HIST)
		MsgStop("A nota fiscal est� paga.","Verifique!")  
		lProcessa := .F.
		Return    
	Case Alltrim(SE1->E1_TIPO) <> 'NCC'
		MsgStop("Esta nota n�o � uma NCC.","Verifique!")
		lProcessa := .F.
		Return		
END CASE 

DbSelectArea("SF1")
dbSetOrder(2)
if !DbSeek(xFilial("SF1")+cCliSe1+cLojSe1+ cNumero) //Nota de Entrada referente ao T�tulo
	MsgStop("Nota referente ao t�tulo n�o encontrada!","Verifique!")
Endif

Private cEmissao := DTOS(SF1->F1_EMISSAO)
Private cNota  := SF1->F1_DOC
Private cNotaSerie := SF1->F1_SERIE
Private cFornecedor := SF1->F1_FORNECE
Private cLoja := SF1->F1_LOJA

DbSelectArea("SD1")
DbSetOrder(3) //D1_FILIAL+DTOS(D1_EMISSAO)+D1_DOC+D1_SERIE+D1_FORNECE+D1_LOJA     
                                                                                             
if !DbSeek(xFilial("SD1")+cEmissao+cNota+cNotaSerie+cFornecedor+cLoja) //Posiciono no Detalhe da Nota de Devolu��o
	MsgStop("Nota n�o encontrada!","Verifique!")
Endif

// Vari�veis para controle de clientes diferentes
aClientesVinculados := {}
aLojaClientesVinculados := {}  // Armazena os clientes encontrados
lClientesDiferentes := .F. // Flag para indicar se h� diverg�ncia

DbSeek(xFilial("SD1")+cEmissao+cNota+cNotaSerie+cFornecedor+cLoja)

While !SD1->(EOF()) .and. SD1->D1_DOC == cNota .and. ;
	SD1->D1_SERIE == cNotaSerie .and. ;
	SD1->D1_FORNECE == cFornecedor .and. ; //Certificando que n�o v� para outra nota
	SD1->D1_LOJA == cLoja

	cDocOri := SD1->D1_NFORI
	cSerieOri := SD1->D1_SERIORI
	_cCliente := SD1->D1_FORNECE
	_cCliLoja := SD1->D1_LOJA
	cTipo := "N"
	cEspecie := "SPED"

	DbSelectArea("SF2")//Posiciono no documento de Saida Original
	DbSetOrder(2) //F2_FILIAL+F2_CLIENTE+F2_LOJA+F2_DOC+F2_SERIE+F2_TIPO+F2_ESPECIE                                                                                                 

	If DbSeek(xFilial("SF2") + _cCliente + _cCliLoja + cDocOri + cSerieOri +  cTipo + cEspecie) 
    	cVendedor := SF2->F2_VEND1


		dbSelectArea("SA3")//Posiciono no Vendedor
		DbSetOrder(1)

		if DbSeek(xFilial("SA3")+cVendedor)
			cCliVend  := SA3->A3_CLIENTE 
			cNomeVend := SA3->A3_NOME
			//Verifica se o cliente j� foi registrado antes
			If AScan(aClientesVinculados,cCliVend) == 0 .and. A3_CLIENTE != "      " //Se n�o for vazio
				AAdd(aClientesVinculados,cCliVend)
				//Se J� tem mais de um cliente diferente, marca como divergente
				if Len(aClientesVinculados) > 1
					lClientesDiferentes := .T.
				EndIf
			EndIf
		Endif
	Endif

	SD1->(dbSkip())
EndDo

 ClientesVinc := alltrim(aClientesVinculados[1]) +  IIF(Len(aClientesVinculados) > 1, ", " + alltrim(aClientesVinculados[2]), "")
// ClientesVincNome := alltrim(aNomeClientesVinculados[1]) +  IIF(Len(aNomeClientesVinculados) > 1 , ", " + alltrim(aNomeClientesVinculados[2]), "")

If lClientesDiferentes
	cMsg := "Aten��o! Esta nota de entrada est� vinculada a notas de sa�da de vendedores diferentes:" + CRLF
	cMsg += "Vendedores encontrados: " + ClientesVinc + CRLF
	cMsg += "Deseja continuar mesmo assim?"

	if MsgYesNo(cMsg, "Clientes Diferentes")
		mBrowNCC()
		MsgInfo("Baixa de devolu��o conclu�da!", "Concluido")
	else
		MsgInfo("Opera��o cancelada pelo usu�rio.", "Aten��o")
        Return .F.  // Retorna falso para indicar cancelamento
	EndIf
else
	mBrowNCC()
EndIf
	
Return
                
********************************************************************************
Static Function mBrowNCC() //Monta Tela para Criar a NCC.***********************
********************************************************************************    

//Local cNomeC  := Posicione("SA1",1,xFilial("SA1")+cCliSe1+cLojSe1,"A1_NOME") 
Local cTitulo := "Devolu��o NCC"   
                            
Private oDlgLib 
Private cSenha := Space(10)  


DbSelectArea("SA1")//Posiciono no Vendedor
DbSetOrder(1)
DbSeek(xFilial("SA1")+SE1->E1_CLIENTE+SE1->E1_LOJA) 

cCliNome := SA1->A1_NOME


DbSelectArea("SE1")

DEFINE MSDIALOG oDlgLib TITLE cTitulo FROM 0,0 TO 230,418 OF oMainWnd PIXEL FONT oMainWnd:oFont 
@ 005,005 TO 100,220

@ 015,012 SAY "T�tulo:"
@ 015,035 GET SE1->E1_NUM     PICTURE "@!" SIZE 45,15 WHEN .F.
@ 015,090 SAY "Tipo:"
@ 015,115 GET SE1->E1_TIPO    PICTURE "@!" SIZE 20,15 WHEN .F. //WHEN F3 "05"
@ 015,155 SAY "Prefixo:"
@ 015,180 GET SE1->E1_PREFIXO PICTURE "@!" SIZE 20,15 WHEN .F. 

@ 030,012 SAY "Cod Cliente:"
@ 030,045 GET SE1-> E1_CLIENTE PICTURE "@!" SIZE 30,15 WHEN .F.
@ 045, 012 SAY "Nome Cliente:"
@ 045,050 GET cCliNome PICTURE "@!" SIZE 100,15 WHEN .F.
@ 030,078 SAY "Loja:"
@ 030,095 GET SE1->E1_LOJA    PICTURE "@!" SIZE 20,15 WHEN .F.
@ 030,155 SAY "Parcela:"
@ 030,180 GET E1_PARCELA    PICTURE "@!" SIZE 20,15 WHEN .F. 

@ 060,012 SAY "Vr. Pagar:" COLOR CLR_HBLUE
@ 060,050 GET nNValor PICTURE "@E 9,999.99" SIZE 30,8 WHEN .T.  
//@ 060,105 Say OemToAnsi("Senha:") COLOR CLR_HBLUE 
//@ 060,130 Get cSenha     SIZE 50,07 Password //Valid FVerSenha() 

@ 073,015 BmpButton Type 01 Action Eval({|| Iif(SenhaNCC(), fConfNCC(), .F.) })
@ 073,050 BmpButton Type 02 Action Eval({|| MsgInfo("Opera��o cancelada", "Aviso"), oDlgLib:End()}) //Cancelar    

ACTIVATE MSDIALOG oDlgLib CENTER

Return
        
Static Function SenhaNCC()
******************************************************************************************************************
*  Valida a senha e grava a autorizacao de reemissao.
*
****
Local lRet	:= .T.


Return(lRet)


******************************************************************************************************************
Static Function fConfNCC() //Grava a autorizacao de reemissao
******************************************************************************************************************

Local aMatSE1  := {}     
Local nOpcao   := 3
Local cCliente := ""
Local cLojaCli := ""
Local cGrpVen  := ""    
Local cNomCli  := ""
Local cNature  := ""     
Local cVend    := ""        
Local cCodUs   := Substr(cUsuario,7,15)
Local cQuerySF1 := "" 
Local cQuerySE1 := ""          

If nNValor == 0
	ApmsgStop("O valor � alterar n�o pode ser igual a ZERO","Favor conferir!")  
	Return 
EndIf


		cQuerySE1 := "UPDATE SE1010 "
		cQuerySE1 += "SET E1_HIST = 'NCR no valor de R$"+cValToChar(nNValor)+" de Devolu��o'" //'NCR no valor de "+nNValor+" '"
		cQuerySE1 += "WHERE E1_NUM ='"+cNumero+"' "
		cQuerySE1 += "AND E1_FILIAL ='"+xFilial("SE1")+"' "
		cQuerySE1 += "AND E1_CLIENTE ='"+cCliSe1+"' "
		cQuerySE1 += "AND E1_LOJA ='"+cLojSe1+"' "
		TcSqlExec( cQuerySE1 )
		
		
		cQuerySF1 := "UPDATE SF1010 "
		cQuerySF1 += "SET F1_ORDPAGO ='PG' "
		cQuerySF1 += "WHERE F1_DOC ='"+cNumero+"' "
		cQuerySF1 += "AND F1_FILIAL ='"+xFilial("SF1")+"' "
		cQuerySF1 += "AND F1_FORNECE ='"+cCliSe1+"' "
		cQuerySF1 += "AND F1_LOJA ='"+cLojSe1+"' "
		TcSqlExec( cQuerySF1 )

MsgInfo("Baixa de devolu��o conclu�da!", "Concluido")

oDlgLib:End()

Return
