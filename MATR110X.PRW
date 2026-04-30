/*
Customização de relatório de Pedido de Compras (Protheus).
- Substitui impressão padrão (MATR110X)
- Gera relatório gráfico em PDF (FWMSPrinter)
- Consulta dados via SQL (SC7 e relacionadas)
- Exibe fornecedor, itens, valores e totais
- Controle de paginação, cabeçalho e rodapé
- Opção de envio por e-mail com anexo em PDF (SMTP)
- Parâmetros dinâmicos via SX1
*/

#include 'fivewin.ch'
#INCLUDE "PROTHEUS.CH"
#INCLUDE "RWMAKE.CH"
#INCLUDE "AP5MAIL.CH"
#include "topconn.ch"
#INCLUDE "RPTDEF.CH"  
#INCLUDE "FWPrintSetup.ch"

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������                     
�������������������������������������������������������������������������ͻ��
���Programa  � LC13R    �Autor �Luis Henrique Robusto� Data �  25/10/04   ���
�������������������������������������������������������������������������͹��
���Desc.     � PEDIDO DE COMPRAS (Emissao em formato Grafico)             ���
�������������������������������������������������������������������������͹��
���Uso       � Compras                                                    ���
�������������������������������������������������������������������������͹��
���DATA      � ANALISTA � MOTIVO                                          ���
�������������������������������������������������������������������������͹��
���          �          �                                                 ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/

// alterar o parametro MV_PCOMPRA e colocar PEDGRF para substituir a impress�o padr�o.

User Function MATR110X()
Private	lEnd		:= .f.,;
		aAreaSC7	:= SC7->(GetArea()),;
		aAreaSA2	:= SA2->(GetArea()),;
		aAreaSA5	:= SA5->(GetArea()),;   
		aAreaSF4	:= SF4->(GetArea()),;
	 	cPerg		:= Padr('PEDGRF',10)


	 	//	aAreaSZF	:= SZF->(GetArea()),;

		//�����������������������
		//�Ajusta os parametros.�
		//�����������������������
		AjustaSX1(cPerg)

		// Se a Impress�o N�o Vier da Tela de Pedido de Compras ent�o Efetua Pergunta de Par�metros
		// Caso contr�rio ent�o posiciona no pedido que foi clicado a op��o imprimir.

		Private	cNumPed  	:= SC7->C7_NUM		// Numero do Pedido de Compras
		Private	lImpPrc		:= .t.	// Imprime os Precos ?
		Private	nTitulo 	:= 2			// Titulo do Relatorio ?
		Private	cObserv1	:= ''			// 1a Linha de Observacoes
		Private	cObserv2	:= ''			// 2a Linha de Observacoes
		Private	cObserv3	:= ''			// 3a Linha de Observacoes
		Private	cObserv4	:= ''			// 4a Linha de Observacoes
		Private	lPrintCodFor:= .f.	// Imprime o Codigo do produto no fornecedor ?

		DbSelectArea('SC7')
		SC7->(DbSetOrder(1))
		If	( ! SC7->(DbSeek(xFilial('SC7') + cNumPed)) )
			Help('',1,'PEDGRF',,OemToAnsi('Pedido n�o encontrado.'),1)
			Return .f.
		EndIf

		//������������������������������Ŀ
		//�Executa a rotina de impressao �
		//��������������������������������
		Processa({ |lEnd| xPrintRel(),OemToAnsi('Gerando o relat�rio.')}, OemToAnsi('Aguarde...'))
		
		//��������������������������������������������Ŀ
		//�Restaura a area anterior ao processamento. !�
		//����������������������������������������������
		RestArea(aAreaSC7)
		RestArea(aAreaSA2)
		RestArea(aAreaSA5)
	 //	RestArea(aAreaSZF)
		RestArea(aAreaSF4)

Return

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  � xPrintRel�Autor �Luis Henrique Robusto� Data �  10/09/04   ���
�������������������������������������������������������������������������͹��
���Desc.     � Imprime a Duplicata...                                     ���
�������������������������������������������������������������������������͹��
���Uso       � Funcao Principal                                           ���
�������������������������������������������������������������������������͹��
���DATA      � ANALISTA � MOTIVO                                          ���
�������������������������������������������������������������������������͹��
���          �          �                                                 ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/

Static Function xPrintRel()
Local _nT
Local nLinObs := 0
	cFileLogo := "logo.png"
	If !File(cFileLogo)
		cFileLogo := "logo.png"//"lgrl" + cEmpAnt + cFilAnt + ".bmp"
	EndIf

Private lEmail		:= .f.
Private	lFlag		:= .t.,;	// Controla a impressao do fornecedor
		nLinha		:= 3000,;	// Controla a linha por extenso
		nLinFim		:= 0,;		// Linha final para montar a caixa dos itens
		lPrintDesTab:= .f.,;	// Imprime a Descricao da tabela (a cada nova pagina)
		cRepres		:= Space(80)

Private	_nQtdReg	:= 0,;		// Numero de registros para intruir a regua
		_nValMerc 	:= 0,;		// Valor das mercadorias
		_nValIPI	:= 0,;		// Valor do I.P.I.
		_nValDesc	:= 0,;		// Valor de Desconto
		_nTotAcr	:= 0,;		// Valor total de acrescimo
		_nTotSeg	:= 0,;		// Valor de Seguro
		_nTotFre	:= 0,;		// Valor de Frete
		_nTotIcmsRet:= 0		// Valor do ICMS Retido

		//�������������������������������������Ŀ
		//�Posiciona nos arquivos necessarios. !�
		//���������������������������������������
		DbSelectArea('SA2')
		SA2->(DbSetOrder(1))
		If	! SA2->(DbSeek(xFilial('SA2')+SC7->(C7_FORNECE+C7_LOJA)))
			Help('',1,'REGNOIS')
			Return .f.
		EndIf
		
		If MsgYesNo("Deseja Enviar Pedido de Compra por Email ?") 
			lEmail := .t.
		Endif

		lViewPDF := !lEmail
		
		//���������������������������������������Ŀ
		//�Define que a impressao deve ser RETRATO�
		//�����������������������������������������
		lAdjustToLegacy := .T.   //.F.
		lDisableSetup  := .T.
		cFilename := Criatrab(Nil,.F.)
		oPrint := FWMSPrinter():New(cFilename, IMP_PDF, lAdjustToLegacy, , lDisableSetup,,,,,,,lViewPDF)
	//	oPrint:Setup()
		oPrint:SetResolution(78)
		oPrint:SetPortrait() // ou SetLandscape()
		oPrint:SetPaperSize(DMPAPER_A4) 
		oPrint:SetMargin(10,10,10,10) // nEsquerda, nSuperior, nDireita, nInferior 
		oPrint:cPathPDF := "C:\TEMP\" // Caso seja utilizada impress�o em IMP_PDF 
		cDiretorio := oPrint:cPathPDF
        //oPrint		:= TMSPrinter():New(OemToAnsi('Pedido de Compras')),;
		
Private	oBrush		:= TBrush():New(,4),;
		oPen		:= TPen():New(0,5,CLR_BLACK),;
		cFileLogo	:= GetSrvProfString('Startpath','') + "logo.png",;
		oFont07		:= TFont():New( "Arial",,07,,.t.,,,,,.f. )
		oFont08		:= TFont():New( "Arial",,08,,.f.,,,,,.f. )
		oFont08n    := TFont():New( "Arial",,08,,.t.,,,,,.f. )
		oFont09		:= TFont():New( "Arial",,09,,.f.,,,,,.f. )
		oFont10		:= TFont():New( "Arial",,10,,.f.,,,,,.f. )
		oFont10n	:= TFont():New( "Arial",,10,,.t.,,,,,.f. )
		oFont11		:= TFont():New( "Arial",,11,,.f.,,,,,.f. )
		oFont12		:= TFont():New( "Arial",,12,,.f.,,,,,.f. )
		oFont12n	:= TFont():New( "Arial",,14,,.t.,,,,,.f. )
		oFont14		:= TFont():New( "Arial",,14,,.f.,,,,,.f. )
		oFont15		:= TFont():New( "Arial",,15,,.f.,,,,,.f. )
		oFont18		:= TFont():New( "Arial",,18,,.f.,,,,,.f. )
		oFont16		:= TFont():New( "Arial",,16,,.f.,,,,,.f. )
		oFont20		:= TFont():New( "Arial",,20,,.f.,,,,,.f. )
		oFont22		:= TFont():New( "Arial",,22,,.f.,,,,,.f. )

	
		//�������������Ŀ
		//�Monta query !�    //SC7.C7_CODPRF, 
		//���������������
		cSELECT :=	'SC7.C7_FILIAL, SC7.C7_NUM, SC7.C7_EMISSAO, SC7.C7_FORNECE, SC7.C7_LOJA, SC7.C7_COND, SC7.C7_CONTATO, SC7.C7_OBS, '+;
					'SC7.C7_ITEM, SC7.C7_UM, SC7.C7_PRODUTO, SC7.C7_DESCRI, SC7.C7_QUANT, '+;
					'SC7.C7_PRECO, SC7.C7_IPI, SC7.C7_TOTAL, SC7.C7_VLDESC, SC7.C7_DESPESA, '+;
					'SC7.C7_SEGURO, SC7.C7_VALFRE, SC7.C7_TES, SC7.C7_ICMSRET, SC7.C7_DATPRF, SC7.C7_USER '

		cFROM   :=	RetSqlName('SC7') + ' SC7 '

		cWHERE  :=	'SC7.D_E_L_E_T_ <>   '+CHR(39) + '*'            +CHR(39) + ' AND '+;
					'SC7.C7_FILIAL  =    '+CHR(39) + xFilial('SC7') +CHR(39) + ' AND '+;
					'SC7.C7_NUM     =    '+CHR(39) + cNumPed        +CHR(39) 

		cORDER  :=	'SC7.C7_FILIAL, SC7.C7_ITEM '

		cQuery  :=	' SELECT '   + cSELECT + ; 
					' FROM '     + cFROM   + ;
					' WHERE '    + cWHERE  + ;
					' ORDER BY ' + cORDER

		TCQUERY cQuery NEW ALIAS 'TRA'   
		
		TcSetField('TRA','C7_DATPRF','D')

		If	! USED()
			MsgBox(cQuery+'. Query errada','Erro!!!','STOP')
		EndIf

		DbSelectArea('TRA')
		Count to _nQtdReg
		ProcRegua(_nQtdReg)
		TRA->(DbGoTop())

		cCompr := TRA->C7_USER
		
		cTipoSC7	:= IIF((SC7->C7_TIPO == 1 .OR. SC7->C7_TIPO == 3),"PC","AE")
		cComprador 	:= UsrFullName(SC7->C7_USER)
		cAlter	 	:= ''
		cAprov	 	:= ''

		If !Empty(SC7->C7_GRUPCOM)
			dbSelectArea("SAJ")
			dbSetOrder(1)
			dbSeek(xFilial("SAJ")+SC7->C7_GRUPCOM)
			While !Eof() .And. SAJ->AJ_FILIAL+SAJ->AJ_GRCOM == xFilial("SAJ")+SC7->C7_GRUPCOM
				If SAJ->AJ_USER != SC7->C7_USER
					cAlter += AllTrim(UsrFullName(SAJ->AJ_USER))+"/"
				EndIf
				dbSelectArea("SAJ")
				dbSkip()
			EndDo
		EndIf

		// Aprovadores
		
		dbSelectArea("SCR")
		dbSetOrder(1)
		dbSeek(xFilial("SCR")+cTipoSC7+SC7->C7_NUM)
		While !Eof() .And. SCR->CR_FILIAL+Alltrim(SCR->CR_NUM) == xFilial("SCR")+Alltrim(SC7->C7_NUM) .And. SCR->CR_TIPO == cTipoSC7
			cAprov += AllTrim(UsrFullName(SCR->CR_USER))+" ["
			Do Case
				Case SCR->CR_STATUS=="03" //Liberado
					cAprov += "Ok"
				Case SCR->CR_STATUS=="04" //Bloqueado
					cAprov += "BLQ"
				Case SCR->CR_STATUS=="05" //Nivel Liberado
					cAprov += "##"
				OtherWise                 //Aguar.Lib
					cAprov += "??"
			EndCase
			cAprov += "] - "
			dbSelectArea("SCR")
			dbSkip()
		Enddo

      	cObServ := ''
		While 	TRA->( ! Eof() )

				xVerPag()

				If	( lFlag )
					//����������Ŀ
					//�Fornecedor�
					//������������
					oPrint:Say(0530,0100,OemToAnsi('Fornecedor:'),oFont10)
					oPrint:Say(0520,0430,AllTrim(SA2->A2_NOME) + '  ('+AllTrim(SA2->A2_COD)+'/'+AllTrim(SA2->A2_LOJA)+')',oFont11)
					oPrint:Say(0580,0100,OemToAnsi('Endere�o:'),oFont10)
					oPrint:Say(0580,0430,SA2->A2_END,oFont11)
					oPrint:Say(0630,0100,OemToAnsi('Munic�pio/U.F.:'),oFont10)
					oPrint:Say(0630,0430,AllTrim(SA2->A2_MUN)+'/'+AllTrim(SA2->A2_EST),oFont11)
					oPrint:Say(0630,1100,OemToAnsi('Cep:'),oFont10)
					oPrint:Say(0630,1270,TransForm(SA2->A2_CEP,'@R 99.999-999'),oFont11)
					oPrint:Say(0680,0100,OemToAnsi('Telefone:'),oFont10)
					oPrint:Say(0680,0430,SA2->A2_TEL,oFont11)
					oPrint:Say(0680,1100,OemToAnsi('CNPJ:'),oFont10)
					oPrint:Say(0680,1270,Transform(SA2->A2_CGC,'@R 99.999.999/9999-99'),oFont11)
					oPrint:Say(0730,0100,OemToAnsi('Contato:'),oFont10)
					oPrint:Say(0730,0430,SC7->C7_CONTATO,oFont11)
					oPrint:Say(0730,1100,OemToAnsi('Email:'),oFont10)
					oPrint:Say(0730,1270,SA2->A2_EMAIL,oFont11)

					//��������������Ŀ
					//�Numero/Emissao�
					//����������������
					oPrint:Box(0530,1900,0700,2300)
					oPrint:Say(0550,1960,OemToAnsi('Numero documento'),oFont10n)
					oPrint:Say(0600,2000,SC7->C7_NUM,oFont18)
					oPrint:Say(0650,2000,Dtoc(SC7->C7_EMISSAO),oFont12n)
					lFlag := .f.
				EndIf
				
				If	( lPrintDesTab )
					oPrint:Box(nLinha-30,100,nLinha+40,2300) 
					oPrint:Say(nLinha+10,0120,OemToAnsi('It'),oFont12n)
					oPrint:Say(nLinha+10,0180,OemToAnsi('C�digo'),oFont12n)
					oPrint:Say(nLinha+10,0420,OemToAnsi('Descri��o'),oFont12n)
					oPrint:Say(nLinha+10,1000,OemToAnsi('Observa��o'),oFont12n)
					oPrint:Say(nLinha+10,1450,OemToAnsi('Un'),oFont12n)
					oPrint:Say(nLinha+10,1520,OemToAnsi('Entrg'),oFont12n)
					oPrint:Say(nLinha+10,1660,OemToAnsi('Qtde'),oFont12n)
					oPrint:Say(nLinha+10,1800,OemToAnsi('Vlr.Unit.'),oFont12n)
					oPrint:Say(nLinha+10,1960,OemToAnsi('Ipi %'),oFont12n)
					oPrint:Say(nLinha+10,2080,OemToAnsi('Valor Total'),oFont12n)
					lPrintDesTab := .f.
					nLinha += 70
				EndIf

				oPrint:Say(nLinha,0120,Right(TRA->C7_ITEM,2),oFont10n)
				cCodPro := ''
				If	( lPrintCodFor )
					DbSelectArea('SA5')
					SA5->(DbSetOrder(1))
					If	SA5->(DbSeek(xFilial('SA5') + SA2->A2_COD + SA2->A2_LOJA + TRA->C7_PRODUTO)) .and. ( ! Empty(SA5->A5_CODPRF) )
						cCodPro := SA5->A5_CODPRF
					Else
						cCodPro := TRA->C7_PRODUTO
					EndIf
				Else
					cCodPro := TRA->C7_PRODUTO
				EndIf	
				
				oPrint:Say(nLinha,1450,TRA->C7_UM,oFont10)
				oPrint:Say(nLinha,1520,DtoC(TRA->C7_DATPRF),oFont10n,,,,1)
			    oPrint:Say(nLinha,1700,Alltrim(TransForm(TRA->C7_QUANT,'@E 99,999,999')),oFont10n,,,,1)

				If	( lImpPrc )
					oPrint:Say(nLinha,1800,AllTrim(TransForm(TRA->C7_PRECO,'@E 999,999.9999')),oFont10n,,,,1)
					oPrint:Say(nLinha,2000,AllTrim(TransForm(TRA->C7_IPI,'@E 99.9')),oFont10n,,,,1)
					oPrint:Say(nLinha,2150,AllTrim(TransForm(TRA->C7_TOTAL,'@E 999,999.9999')),oFont10n,,,,1)
				EndIf

				SB1->(dbSetOrder(1), dbSeek("01    "+TRA->C7_PRODUTO))
				cDesc := AllTrim(SB1->B1_ESPECIF)
				cObservacao := SubStr(AllTrim(TRA->C7_OBS), RAT('SC:',AllTrim(TRA->C7_OBS))+ 3)
								
				nLinCod := MlCount(cCodPro,10)

				_nLinhas := MlCount(cDesc,45)

				_nLinhasObs := MlCount(SubStr(AllTrim(TRA->C7_OBS), RAT('SC:',AllTrim(TRA->C7_OBS))+ 3),30)

				For _nT := 1 To Max(Max(_nLinhas,nLinCod),_nLinhasObs)
					If _nT <= nLinCod
						oPrint:Say(nLinha,0180,MemoLine(cCodPro,10,_nT),oFont10)
        			Endif
					If _nT <= _nLinhas
						oPrint:Say(nLinha,0420,Capital(MemoLine(cDesc,40,_nT)),oFont10,,0)
					Endif
					If _nT <= _nLinhasObs
						oPrint:Say(nLinha,1000,Capital(MemoLine(SubStr(AllTrim(TRA->C7_OBS), RAT('SC:',AllTrim(TRA->C7_OBS))+ 3),30,_nT)),oFont10,,0)
					Endif
					nLinha+=40
				Next _nT

				oPrint:Line(nLinha,100,nLinha,2300)

				nLinha+=30

				_nValMerc 		+= TRA->C7_TOTAL
				_nValIPI		+= (TRA->C7_TOTAL * TRA->C7_IPI) / 100
				_nValDesc		+= TRA->C7_VLDESC
				_nTotAcr		+= TRA->C7_DESPESA
				_nTotSeg		+= TRA->C7_SEGURO
				_nTotFre		+= TRA->C7_VALFRE

				If	( Empty(TRA->C7_TES) )
					_nTotIcmsRet	+= TRA->C7_ICMSRET
				Else
					DbSelectArea('SF4')
					SF4->(DbSetOrder(1))
					If	SF4->(DbSeek(xFilial('SF4') + TRA->C7_TES))
						If	( AllTrim(SF4->F4_INCSOL) == 'S' )
							_nTotIcmsRet	+= TRA->C7_ICMSRET
						EndIf
					EndIf
				EndIf

				       
				cObserv += AllTrim(TRA->C7_OBS)+' ' 
				

			
				
			IncProc()
			TRA->(DbSkip())	

		End
		nLinha-=30

		xVerPag()

		//����������������������������Ŀ
		//�Imprime TOTAL DE MERCADORIAS�
		//������������������������������
		If	( lImpPrc )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor Mercadorias ',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nValMerc,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//������������������������Ŀ
		//�Imprime TOTAL DE I.P.I. �
		//��������������������������
		If	( lImpPrc ) .and. ( _nValIpi > 0 )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor de I. P. I. (+)',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nValIpi,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//�������������������������Ŀ
		//�Imprime TOTAL DE DESCONTO�
		//���������������������������
		If	( lImpPrc ) .and. ( _nValDesc > 0 )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor de Desconto (-)',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nValDesc,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//���������������������������Ŀ
		//�Imprime TOTAL DE ACRESCIMO �
		//�����������������������������
		If	( lImpPrc ) .and. ( _nTotAcr > 0 )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor de Acresc. (+)',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nTotAcr,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//������������������������Ŀ
		//�Imprime TOTAL DE SEGURO �
		//��������������������������
		If	( lImpPrc ) .and. ( _nTotSeg > 0 )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor de Seguro (+)',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nTotSeg,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//�����������������������Ŀ
		//�Imprime TOTAL DE FRETE �
		//�������������������������
		If	( lImpPrc ) .and. ( _nTotFre > 0 )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor de Frete (+)',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nTotFre,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//�����������������������Ŀ
		//�Imprime ICMS RETIDO    �
		//�������������������������
		If	( lImpPrc ) .and. ( _nTotIcmsRet > 0 )
			oPrint:Line(nLinha,1390,nLinha+80,1390)
			oPrint:Line(nLinha,1900,nLinha+80,1900)
			oPrint:Line(nLinha,2300,nLinha+80,2300)
			oPrint:Say(nLinha+30,1400,'Valor de ICMS Retido',oFont12)
			oPrint:Say(nLinha+30,2050,TransForm(_nTotIcmsRet,'@E 9,999,999.99'),oFont11,,,,1)
			nLinha += 80
			oPrint:Line(nLinha,1390,nLinha,2300)
		EndIf

		xVerPag()

		//�����������������������Ŀ
		//�Imprime o VALOR TOTAL !�
		//�������������������������
//		oPrint:FillRect({nLinha,1390,nLinha+80,2300},oBrush)
		oPrint:Line(nLinha,1390,nLinha+80,1390)
		oPrint:Line(nLinha,1900,nLinha+80,1900)
		oPrint:Line(nLinha,2300,nLinha+80,2300)
		oPrint:Say(nLinha+30,1400,'VALOR TOTAL ',oFont12)
		If	( lImpPrc )
			oPrint:Say(nLinha+30,2050,TransForm(_nValMerc + _nValIPI - _nValDesc + _nTotAcr	+ _nTotSeg + _nTotFre + _nTotIcmsRet,'@E 9,999,999.99'),oFont11,,,,1)
		EndIf
		nLinha += 80
		xVerPag()
		oPrint:Line(nLinha,1390,nLinha,2300)
		nLinha += 70

		xVerPag()

		//����������������������������������������Ŀ
		//�Imprime as observacoes dos parametros. !�
		//������������������������������������������
		
		// cObserv1 := Left(cObserv,70)
		// cObserv2 := SubStr(cObserv,71,70)
		// cObserv3 := SubStr(cObserv,141,70)
		// cObserv4 := SubStr(cObserv,211,70)
		
		// oPrint:Say(nLinha,0100,OemToAnsi('Observa��es/USO:'),oFont12)
		// oPrint:Say(nLinha,0500,cObserv1,oFont12n)
		// nLinha += 60
		// xVerPag()
		// If	( ! Empty(cObserv2) )
		// 	oPrint:Say(nLinha,0500,cObserv2,oFont12n)
		// 	nLinha += 60
		// 	xVerPag()
		// EndIf	
		// If	( ! Empty(cObserv3) )
		// 	oPrint:Say(nLinha,0500,cObserv3,oFont12n)
		// 	xVerPag()
		// 	nLinha += 60
		// EndIf	
		// If	( ! Empty(cObserv4) )
		// 	oPrint:Say(nLinha,0500,cObserv4,oFont12n)
		// 	xVerPag()
		// 	nLinha += 60
		// 	xVerPag()
		// EndIf

		// nLinha += 20
		// xVerPag()

		//�����������������������������������������������Ŀ
		//�Imprime o Representante comercial do fornecedor�
		//�������������������������������������������������   
		/*
		DbSelectArea('SZF')
		SZF->(DbSetOrder(1))
		If	SZF->(DbSeek(xFilial('SZF') + SA2->A2_COD + SA2->A2_LOJA))
			If	( ! Empty(SZF->ZF_REPRES) )
				oPrint:Say(nLinha,0100,OemToAnsi('Representante:'),oFont12)
				oPrint:Say(nLinha,0500,AllTrim(SZF->ZF_REPRES) + Space(5) + AllTrim(SZF->ZF_TELREPR) + Space(5) + AllTrim(SZF->ZF_FAXREPR),oFont12n)
				nLinha += 60
				xVerPag()
			EndIf
		EndIf	
        */
		nLinha += 20
		xVerPag()

		//�������������������������������������������Ŀ
		//�Imprime a linha de prazo pagamento/entrega!�
		//���������������������������������������������
		oPrint:Say(nLinha,0100,OemToAnsi('Prazo Pagamento:'),oFont12)
		If !Empty(SC7->C7_COND)
			If SE4->(dbSetOrder(1), dbSeek(xFilial("SE4")+SC7->C7_COND))
				oPrint:Say(nLinha,0500,SE4->E4_CODIGO + ' - ' + SE4->E4_DESCRI,oFont12n)
			Endif
		Else
			oPrint:Say(nLinha,0500,'_____________________',oFont12n)
		Endif
		
//		oPrint:Say(nLinha,1120,OemToAnsi('Prazo Entrega:'),oFont12)
//		oPrint:Say(nLinha,1500,'___________________________',oFont12n)
		nLinha += 60
  		xVerPag()

		nLinha += 20
		xVerPag()

		//�����������������������������������Ŀ
		//�Imprime a linha de transportadora !�
		//�������������������������������������
/*		oPrint:Say(nLinha,0100,OemToAnsi('Transportadora:'),oFont12)
		oPrint:Say(nLinha,0500,'____________________________________________________',oFont12n)*/
		nLinha += 60
		xVerPag()

		nLinha += 20
		xVerPag()

		//������������������Ŀ
		//�Imprime o Contato.�
		//��������������������
		If	( ! Empty(SA2->A2_CONTATO) )
			oPrint:Say(nLinha,0100,OemToAnsi('Contato: '),oFont12)
			oPrint:Say(nLinha,0500,SA2->A2_CONTATO,oFont12n)
			nLinha += 60
			xVerPag()
		EndIf

		oPrint:Line(nLinha,0100,nLinha,2300)
		nLinha += 10
		xVerPag()

		xRodape()

		TRA->(DbCloseArea())

		
/*		If !Empty(_nQtdReg)
			U_EPed(cNumPed,'')					
		Endif
  */		
		//���������������������������������������������
		//�Imprime em Video, e finaliza a impressao. !�
		//���������������������������������������������	
		oPrint:Preview()
		
		If lEmail
			U_PedMail()
		Endif
Return

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  � xCabec() �Autor �Luis Henrique Robusto� Data �  25/10/04   ���
�������������������������������������������������������������������������͹��
���Desc.     � Imprime o Cabecalho do relatorio...                        ���
�������������������������������������������������������������������������͹��
���Uso       � Funcao Principal                                           ���
�������������������������������������������������������������������������͹��
���DATA      � ANALISTA �  MOTIVO                                         ���
�������������������������������������������������������������������������͹��
���          �          �                                                 ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/

Static Function xCabec()

		//���������������������������������Ŀ
		//�Imprime o cabecalho da empresa. !�
		//�����������������������������������
		oPrint:SayBitmap(050,100,cFileLogo,1050,260)
		oPrint:Say(050,1300,AllTrim(Upper(SM0->M0_NOMECOM)),oFont16)
		oPrint:Say(135,1300,AllTrim(SM0->M0_ENDCOB),oFont11)
		oPrint:Say(180,1300,Capital(AllTrim(SM0->M0_CIDCOB))+'/'+AllTrim(SM0->M0_ESTCOB)+ '  -  ' + AllTrim(TransForm(SM0->M0_CEPCOB,'@R 99.999-999')) + '  -  ' + AllTrim(SM0->M0_TEL),oFont11)
		oPrint:Say(225,1300,AllTrim('www.tropeira.com.br'),oFont11)
		oPrint:Line(265,1300,265,2270)
		oPrint:Say(300,1300,TransForm(SM0->M0_CGC,'@R 99.999.999/9999-99'),oFont12)
		oPrint:Say(300,1850,SM0->M0_INSC,oFont12)

		//�������������������Ŀ
		//�Titulo do Relatorio�
		//���������������������
		If	( nTitulo == 1 ) // Cotacao
			oPrint:Say(0400,0800,OemToAnsi('Cota��o de Compras'),oFont22)
		Else
			oPrint:Say(0400,0800,OemToAnsi('Pedido de Compras'),oFont22)
		EndIf

Return

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  � xRodape()�Autor �Luis Henrique Robusto� Data �  25/10/04   ���
�������������������������������������������������������������������������͹��
���Desc.     � Imprime o Rodape do Relatorio....                          ���
�������������������������������������������������������������������������͹��
���Uso       � Funcao Principal                                           ���
�������������������������������������������������������������������������͹��
���DATA      � ANALISTA �  MOTIVO                                         ���
�������������������������������������������������������������������������͹��
���          �          �                                                 ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/

Static Function xRodape()

oPrint:Say(2910,0100,'NOTA: A mercadoria ser� recebida mediante a indica��o do n�mero do Pedido de Compras na Nota Fiscal. ',oFont12n)
oPrint:Line(2950,0100,2950,2300)     
oPrint:Say(2990,0100,"Comprador Responsavel  : "+Substr(cComprador,1,40),oFont11)
//oPrint:Say(3030,0100,"Comprador Alternativos : "+If( Len(cAlter) > 0 , Substr(cAlter,001,130) , " " ),oFont11)
//oPrint:Say(3070,0500,If( Len(cAlter) > 0 , Substr(cAlter,131,130) , " " ),oFont11)
//oPrint:Say(3110,0100,"Aprovador(es) : "+If( Len(cAprov) > 0 , Substr(cAprov,001,140) , " " ),oFont11)
//oPrint:Say(3150,0500,If( Len(cAprov) > 0 , Substr(cAprov,141,140) , " " ),oFont11)
//	oPrint:Line(3080,0100,3080,2300)
//   oPrint:Say(3120,1050,AllTrim(SM0->M0_TEL),oFont16)
//	oPrint:Line(3200,0100,3200,2300)
/*   oPrint:Say(3300,0100,'ENVIAR CERTIFICADO DE QUALIDADE E MENCIONAR N� DO NOSSO PEDIDO NA NOTA FISCAL',oFont08n)
   IF SB1->B1_TIPO == 'MP'
	   oPrint:Say(3330,0100,'O PEDIDO REPRESENTA INTEN��O DE COMPRAS FIRME, POR�M AS ENTREGAS OCORRER�O RESPEITANDO O KANBAN SEMANAL. EVENTUAIS EXCESSOS SER�O AJUSTADOS NO M�S POSTERIOR',oFont08n)
	ENDIF
   oPrint:Say(3360,0100,'ENDERE�O DE ENTREGA = RUA JO�O NINC�O, 328 CAPUAVA MAU�',oFont08n) 
   oPrint:Say(3390,0100,'N�O RECEBEREMOS NOTAS COM MAIS DE 24 HORAS DA DATA DE EMISSAO',oFont08n) */
	oPrint:EndPage()
Return

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  � xVerPag()�Autor �Luis Henrique Robusto� Data �  25/10/04   ���
�������������������������������������������������������������������������͹��
���Desc.     � Verifica se deve ou nao saltar pagina...                   ���
�������������������������������������������������������������������������͹��
���Uso       � Funcao Principal                                           ���
�������������������������������������������������������������������������͹��
���DATA      � ANALISTA �  MOTIVO                                         ���
�������������������������������������������������������������������������͹��
���          �          �                                                 ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/

Static Function xVerPag()

	//�������������������������������Ŀ
	//�Inicia a montagem da impressao.�
	//���������������������������������
	If	( nLinha >= 2800 )

		If	( ! lFlag )
			xRodape()
			oPrint:EndPage()
			nLinha:= 600
		Else
			nLinha:= 800
		EndIf

		oPrint:StartPage()
		xCabec()

		lPrintDesTab := .t.

	EndIf
	

Return

/*
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
�������������������������������������������������������������������������ͻ��
���Programa  � AjustaSX1�Autor �Luis Henrique Robusto� Data �  25/10/04   ���
�������������������������������������������������������������������������͹��
���Desc.     � Ajusta o SX1 - Arquivo de Perguntas..                      ���
�������������������������������������������������������������������������͹��
���Uso       � Funcao Principal                                           ���
�������������������������������������������������������������������������͹��
���DATA      � ANALISTA � MOTIVO                                          ���
�������������������������������������������������������������������������͹��
���          �          �                                                 ���
�������������������������������������������������������������������������ͼ��
�����������������������������������������������������������������������������
�����������������������������������������������������������������������������
*/

Static Function AjustaSX1(cPerg)
Local	aRegs   := {},;
		_sAlias := Alias(),;
		nX

		//���������������������������Ŀ
		//�Campos a serem grav. no SX1�
		//�aRegs[nx][01] - X1_GRUPO   �
		//�aRegs[nx][02] - X1_ORDEM   �
		//�aRegs[nx][03] - X1_PERGUNTE�
		//�aRegs[nx][04] - X1_PERSPA  �
		//�aRegs[nx][05] - X1_PERENG  �
		//�aRegs[nx][06] - X1_VARIAVL �
		//�aRegs[nx][07] - X1_TIPO    �
		//�aRegs[nx][08] - X1_TAMANHO �
		//�aRegs[nx][09] - X1_DECIMAL �
		//�aRegs[nx][10] - X1_PRESEL  �
		//�aRegs[nx][11] - X1_GSC     �
		//�aRegs[nx][12] - X1_VALID   �
		//�aRegs[nx][13] - X1_VAR01   �
		//�aRegs[nx][14] - X1_DEF01   �
		//�aRegs[nx][15] - X1_DEF02   �
		//�aRegs[nx][16] - X1_DEF03   �
		//�aRegs[nx][17] - X1_F3      �
		//�����������������������������

		//��������������������������������������������Ŀ
		//�Cria uma array, contendo todos os valores...�
		//����������������������������������������������
		aAdd(aRegs,{cPerg,'01','Numero do Pedido   ?','Numero do Pedido   ?','Numero do Pedido   ?','mv_ch1','C', 6,0,0,'G','','mv_par01','','','','SC7'})
		aAdd(aRegs,{cPerg,'02','Imprime precos     ?','Imprime precos     ?','Imprime precos     ?','mv_ch2','N', 1,0,1,'C','','mv_par02',OemToAnsi('N�o'),'Sim','',''})
		aAdd(aRegs,{cPerg,'03','Titulo do Relatorio?','Titulo do Relatorio?','Titulo do Relatorio?','mv_ch3','N', 1,0,1,'C','','mv_par03',OemToAnsi('Cota��o'),'Pedido','',''})
		aAdd(aRegs,{cPerg,'04',OemToAnsi('Observa��es'),'Observa��es         ','Observa��es         ','mv_ch4','C',70,0,1,'G','','mv_par04','','','',''})
		aAdd(aRegs,{cPerg,'05','                    ','                    ','                    ','mv_ch5','C',70,0,1,'G','','mv_par05','','','',''})
		aAdd(aRegs,{cPerg,'06','                    ','                    ','                    ','mv_ch6','C',70,0,0,'G','','mv_par06','','','',''})
		aAdd(aRegs,{cPerg,'07','                    ','                    ','                    ','mv_ch7','C',70,0,0,'G','','mv_par07','','','',''})
		aAdd(aRegs,{cPerg,'08','Imp. Cod. Prod. For?','Imp. Cod. Prod. For?','Imp. Cod. Prod. For?','mv_ch8','N', 1,0,1,'C','','mv_par08',OemToAnsi('Sim'),OemToAnsi('N�o'),'',''})

		DbSelectArea('SX1')
		SX1->(DbSetOrder(1))

		For nX:=1 to Len(aRegs)
			If !SX1->(DbSeek(aRegs[nx][01]+aRegs[nx][02]))
				RecLock('SX1',.t.)
				Replace SX1->X1_GRUPO		With aRegs[nx][01]
				Replace SX1->X1_ORDEM   	With aRegs[nx][02]
				Replace SX1->X1_PERGUNTE	With aRegs[nx][03]
				Replace SX1->X1_PERSPA		With aRegs[nx][04]
				Replace SX1->X1_PERENG		With aRegs[nx][05]
				Replace SX1->X1_VARIAVL		With aRegs[nx][06]
				Replace SX1->X1_TIPO		With aRegs[nx][07]
				Replace SX1->X1_TAMANHO		With aRegs[nx][08]
				Replace SX1->X1_DECIMAL		With aRegs[nx][09]
				Replace SX1->X1_PRESEL		With aRegs[nx][10]
				Replace SX1->X1_GSC			With aRegs[nx][11]
				Replace SX1->X1_VALID		With aRegs[nx][12]
				Replace SX1->X1_VAR01		With aRegs[nx][13]
				Replace SX1->X1_DEF01		With aRegs[nx][14]
				Replace SX1->X1_DEF02		With aRegs[nx][15]
				Replace SX1->X1_DEF03		With aRegs[nx][16]
				Replace SX1->X1_F3   		With aRegs[nx][17]
				MsUnlock('SX1')
			Endif
		Next nX

Return


User Function PedMail()
Private _PedCom
Private nTarget:=0
Private cFOpen :=""
Private nOpc   := 0
Private bOk    := {||nOpc:=1,_PedCom:End()}
Private bCancel:= {||nOpc:=0,_PedCom:End()} 
Private lCheck1:=.F.
Private lCheck2:=.T.
Private lCheck3:=.f.


_cPara   :=SA2->A2_EMAIL
_cContato:=PadR(SA2->A2_CONTATO,30)



Define MsDialog _PedCom Title "Pedido de Compras por Email" From 050,037 To 220,774 Pixel 
@ 037,006 To 80,380 Title OemToAnsi("  Dados do Pedido ") 
@ 045,010 Say "Pedido:" Color CLR_HBLUE // Size 25,8 
@ 045,040 Get cNumPed Picture "@!" When .f.
@ 045,097 Say "Email:" Color CLR_HBLUE //Size 25,8 
@ 045,125 Get _cPara Picture "@" Size 150,08
@ 055,010 Say "Fornecedor: " Color CLR_HBLUE
@ 055,042 Say SA2->A2_NOME Color CLR_HRED Object oCliente //Size 19,8 
@ 065,010 Say "Contato: " Color CLR_HBLUE //Size 25,8 
@ 065,042 Say _cContato Object oAutor
@ 065,042 Get _cContato Picture "@" Size 150,08

// @ 90,010 To 192,360
// @ 98,015 Get mCorpo MEMO Size 350,90

Activate MsDialog _PedCom On Init EnchoiceBar(_PedCom,bOk,bCancel,,) Centered
If nOpc == 1
	cAnexo := 'C:\TEMP\'+cFilename+'.PDF'
	EnvMail(cAnexo, cNumPed, _cPara, _cContato)
EndIf
Return .t.




Static Function EnvMail(cAnexo,cNumPed,cPara,cContato)
Local mCorpo := ""
Local cNL := Chr(13)+Chr(10)
Private cAssunto     := 'Pedido de Compras - No. ' + cNumPed
Private nLineSize    := 60
Private nTabSize     := 3
Private lWrap        := .T. 
Private nLine        := 0
Private cTexto       := ""
Private lServErro	   := .T.
Private cServer  := Trim(GetMV("MV_RELSERV")) // smtp.tecnotron.ind.br
Private cDe 	:= Trim(GetMV("MV_RELACNT"))
Private cPass    := Trim(GetMV("MV_RELPSW"))  // 
Private lAutentic	:= GetMv("MV_RELAUTH",,.F.)
Private aTarget  :={cAnexo}
Private nTarget := 0
Private lCheck1 := .F.
Private lCheck2 := .f.

cCC := "email do usuário"
cAnexos:=cAnexo
CPYT2S(cAnexos,GetSrvProfString("Startpath", "")+'emailanexos\',.T.)
cAnexos:=GetSrvProfString("Startpath", "")+'emailanexos\'+SubStr(AllTrim(cAnexos),RAT('\',AllTrim(cAnexos))+1)
lServERRO 	:= .F.
                    
CONNECT SMTP                         ;
SERVER 	 GetMV("MV_RELSERV"); 	// Nome do servidor de e-mail
ACCOUNT  GetMV("MV_RELACNT"); 	// Nome da conta a ser usada no e-mail
PASSWORD GetMV("MV_RELPSW") ; 	// Senha
Result lConectou  

mCorpo := '<!DOCTYPE html>' + cNL + ;
	'<html>' + cNL + ;
	'<head>' + cNL + ;
	'<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">' + cNL + ;
	'<title>Pedido de Compras</title>' + cNL + ;
	'</head>' + cNL + ;
	'<body style="margin:0;padding:0;background:#ffffff;">' + cNL + ;
	'<table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="padding:0;margin:0;background:#ffffff;border-collapse:collapse;mso-table-lspace:0pt;mso-table-rspace:0pt;">' + cNL + ;
	'  <tr>' + cNL + ;
	'    <td align="center" style="padding:0;margin:0;line-height:0;font-size:0;vertical-align:top;">' + cNL + ;
	'      <table role="presentation" width="640" cellspacing="0" cellpadding="0" border="0" style="background:#ffffff;border:1px solid #e5e7eb;border-radius:6px;overflow:hidden;font-family:Arial,Helvetica,sans-serif;color:#111827;border-collapse:collapse;mso-table-lspace:0pt;mso-table-rspace:0pt;">' + cNL + ;
	'        <tr>' + cNL + ;
	'          <td style="padding:14px 20px;background:#CD001A;color:#ffffff;font-size:16px;font-weight:bold;letter-spacing:0.2px;">Pedido de Compras</td>' + cNL + ;
	'        </tr>' + cNL + ;
	'        <tr>' + cNL + ;
	'          <td style="padding:20px;font-size:14px;line-height:1.6;">' + cNL + ;
	'            <p style="margin:0 0 12px 0;">Sr.(a) ' + '<strong>' + AllTrim(_cContato) + '</strong>,</p>' + cNL + ;
	'            <p style="margin:0 0 12px 0;">Segue em anexo o pedido de compras n&uacute;mero ' + ;
	'              <span style="display:inline-block;background:#FFC72C;color:#7A1E00;padding:3px 8px;border-radius:999px;font-weight:bold;">' + cNumPed + '</span>.</p>' + cNL + ;
	'            <p style="margin:0;">Se precisar de algum ajuste ou informa&ccedil;&atilde;o adicional, fico &agrave; disposi&ccedil;&atilde;o.</p>' + cNL + ;
	'          </td>' + cNL + ;
	'        </tr>' + cNL + ;
	'        <tr>' + cNL + ;
	'          <td style="padding:16px 20px;background:#FFF4CC;border-top:1px solid #F2D17A;font-size:12px;color:#3a0c12;">' + cNL + ;
	'            <strong>LINCON IND&Uacute;STRIA LTDA.</strong> <span style="color:#CD001A;">|</span> <a href="https://www.tropeira.com.br" style="color:#CD001A;text-decoration:none;">www.tropeira.com.br</a>' + cNL + ;
	'          </td>' + cNL + ;
	'        </tr>' + cNL + ;
	'      </table>' + cNL + ;
	'    </td>' + cNL + ;
	'  </tr>' + cNL + ;
	'</table>' + cNL + ;
	'</body>' + cNL + ;
	'</html>'

lRet := .f.
lEnviado := .f.
If lAutentic
	lRet := Mailauth(cDe,cPass)
Endif
If lRet  
	cPara   := Rtrim(cPara)
	cCC		:= Rtrim(cCC)    
	cAssunto:= Rtrim(cAssunto)  
	
	SEND MAIL 	FROM cDe ;
		 		To cPara ;
	    	    CC cCc;
		 		SUBJECT	cAssunto ; 
		 		Body mCorpo;		
		 		ATTACHMENT cAnexos;
		 		RESULT lEnviado

	DISCONNECT SMTP SERVER
Endif
If !lConectou .Or. !lEnviado
	cMensagem := ""
	GET MAIL ERROR cMensagem 
	Alert(cMensagem)
Endif          
FERASE(cAnexos)
Return                      



