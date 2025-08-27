#INCLUDE "TOTVS.CH"
/*
Descricao
O ponto de entrada POGetProd � executado na requisi��o de consulta dos produtos ap�s informar os par�metros de pesquisa.
Com este ponto de entrada, � poss�vel adicionar e remover produtos da pesquisa, al�m de poder adicionar de forma n�o obrigat�ria at� duas informa��es por produto para mostrar no card da pesquisa.

As duas informa��es customizadas que poder�o ser adicionadas a um card na pesquisa ter�o tr�s atributos cada uma.

O primeiro � "CustomLabel", que � referente a um r�tulo ou descri��o do valor que ser� adicionado. 

O segundo � "CustomValue", que � referente ao valor vinculado ao r�tulo criado. Ex.: oJson["CustomLabel"] := "M�quina", oJson["CustomValue"] := "Injetora".

O terceiro � "CustomLink", que � referente ao link que ser� aberto no navegador quando o usu�rio clicar no campo de valor.

Obs.:

Para mostrar a informa��o customizada no card de pesquisa, o �nico atributo de preenchimento obrigat�rio � o "CustomValue".

Se o atributo "CustomLink" for informado, o atributo "CustomValue" ser� um link que ser� aberto no navegador, caso contr�rio, ser� apenas um campo texto.
*/ 

User Function POGetProd()
    //Local aAreaSB1  := SB1->(GetArea())
    //Local aAreaSB8  := SB8->(GetArea())
    Local aItemsObj := PARAMIXB[1]
    Local cAliasSB8 := GetNextAlias()
    Local cForm     := PARAMIXB[2]
    Local cLocal    := ""
    Local cQuerySB8 := ""
    Local nLenArr   := Len(aItemsObj)
    Local nSaldo    := 0
    Local nX        := 0
    Local oJson     := Nil
    Local lEmpPrev  := .T. //lQtdPrev  := (GetMV("MV_QTDPREV") == "S")   
                           //Pegando conte�do do par�metro
     
    //Adicionando novo card de produto no retorno da pesquisa
    If AllTrim(cForm) == "000007"
        For nX:=1 To nLenArr
            //Adicionando informa��es customizadas ao card de um produto na pesquisa
            dbSelectArea("SB1")
            SB1->(dbSetOrder(1))
            Conout("Produto: " + AllTrim(aItemsObj[nX]["Code"]) )
            If SB1->(MsSeek(xFilial("SB1") + AllTrim(aItemsObj[nX]["Code"])))
                cLocal  := SB1->B1_LOCPAD
                
                Conout("Produto: " + AllTrim(aItemsObj[nX]["Code"]) )

                cQuerySB8 := "SELECT *"
                cQuerySB8 += " FROM " + RetSqlName("SB8")
                cQuerySB8 += " WHERE B8_FILIAL  = '01IN01' " 
                cQuerySB8 +=   " AND B8_COD     = '" + AllTrim(aItemsObj[nX]["Code"]) + "'"
                cQuerySB8 +=   " AND B8_LOCAL   = '" + cLocal + "'"
                cQuerySB8 +=   " AND B8_SALDO <> 0 "
                cQuerySB8 +=   " AND D_E_L_E_T_ = ' '"
    
                dbUseArea(.T., "TOPCONN", TcGenQry( , , cQuerySB8), cAliasSB8, .T., .T.)
                While (cAliasSB8)->(!Eof())
                    //nSaldo += SaldoSB2(,,,,,cAliasSB2,,,,,)
                    nSaldo := SB8Saldo(Nil, Nil, Nil, Nil, cAliasSB8, lEmpPrev, .T.)
                    Conout("Saldo no armaz�m padr�o (" + CValToChar(nSaldo) + ")" )
                    (cAliasSB8)->(dbSkip())
                End
    
                (cAliasSB8)->(dbCloseArea())
    
                aItemsObj[nX]["CustomLabel1"] := "Saldo no armaz�m padr�o (" + cLocal + ")"
                aItemsObj[nX]["CustomValue1"] := CValToChar(nSaldo)
                aItemsObj[nX]["CustomLink1"]  := ""
    
                nSaldo := 0

            EndIf

        Next nX
    
      Conout("antes do if"  )
        //Adicionando novo card de produto no retorno da pesquisa
        If AllTrim(cForm) == "000007"
          Conout("dentro do if"  )
            oJson := JsonObject():New()
            oJson["Code"]         := "PRODUTO3"
            oJson["Description"]  := "DESCRICAO PRODUTO 3"
            oJson["CustomLabel1"] := ""
            oJson["CustomValue1"] := ""
            oJson["CustomLink1"]  := ""
            oJson["CustomLabel2"] := ""
            oJson["CustomValue2"] := ""
            oJson["CustomLink2"]  := ""
            aAdd(aItemsObj, oJson)
        EndIf
    
        //excluindo card de produto do retorno da pesquisa
        nX := Ascan(aItemsObj,{|x| AllTrim(x["Code"]) == "PRODUTO"})
        If nX > 0
            aDel(aItemsObj, nX)
            aSize(aItemsObj, Len(aItemsObj)-1)
        EndIf
Else
      Conout("formulario nao � 000007: "  )
EndIf 
    FreeObj(oJson)   
 
Return aItemsObj
