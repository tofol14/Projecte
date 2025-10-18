Option Explicit

' Constants de PowerPoint que necessitem
Private Const ppLayoutTitleAndContent As Long = 2
Private Const ppLayoutTitleOnly As Long = 11
Private Const ppBody As Long = 2
Private Const ppObject As Long = 7
Private Const msoPlaceholder As Long = 14
Private Const msoTrue As Long = -1

' Aquesta subrutina crea una diapositiva de contingut (títol + cos) de forma segura
Private Sub AddContentSlide(ByVal oPres As Presentation, ByVal slideIndex As Long, ByVal sTitle As String, ByVal sContent As String)
    On Error Resume Next
    
    Dim oSlide As Slide
    Dim oShape As Shape
    
    Set oSlide = oPres.Slides.Add(slideIndex, ppLayoutTitleAndContent)
    
    ' Comprovem si s'ha creat la diapositiva
    If oSlide Is Nothing Then
        MsgBox "Error al crear la diapositiva", vbCritical
        Exit Sub
    End If
    
    ' Assigna el títol amb control d'errors
    If Not oSlide.Shapes.Title Is Nothing Then
        oSlide.Shapes.Title.TextFrame.TextRange.Text = sTitle
    End If
    
    ' Cerca la forma del cos principal i hi afegeix el contingut
    For Each oShape In oSlide.Shapes
        If oShape.Type = msoPlaceholder Then
            If oShape.PlaceholderFormat.Type = ppBody Or oShape.PlaceholderFormat.Type = ppObject Then
                oShape.TextFrame.TextRange.Text = sContent
                Exit For
            End If
        End If
    Next oShape
    
    On Error GoTo 0
    Set oSlide = Nothing
    Set oShape = Nothing
End Sub

' Aquesta subrutina crea una diapositiva de només títol (per la portada i el final)
Private Sub AddTitleSlide(ByVal oPres As Presentation, ByVal slideIndex As Long, ByVal sTitle As String, ByVal sSubtitle As String)
    On Error Resume Next
    
    Dim oSlide As Slide
    
    Set oSlide = oPres.Slides.Add(slideIndex, ppLayoutTitleOnly)
    
    ' Comprovem si s'ha creat la diapositiva
    If oSlide Is Nothing Then
        MsgBox "Error al crear la diapositiva de títol", vbCritical
        Exit Sub
    End If
    
    With oSlide.Shapes.Title.TextFrame.TextRange
        .Text = sTitle
        .Font.Size = 32
    End With
    
    If sSubtitle <> "" Then
        With oSlide.Shapes.Title.TextFrame.TextRange.InsertAfter(vbCrLf & vbCrLf & sSubtitle)
            .Font.Size = 24
            .Font.Italic = msoTrue
        End With
    End If
    
    On Error GoTo 0
    Set oSlide = Nothing
End Sub

' =================================================================================
' Subrutina Principal: L'has d'executar des del menú de Macros
' =================================================================================
Public Sub CrearPresentacioTecnicaSmartOffice_V6()
    ' Declaració de variables
    Dim oPres As Presentation
    Dim sTitol As String
    Dim sContingut As String
    Dim slideIndex As Long

    ' Comprovació de seguretat: assegura't que hi ha una presentació oberta
    If Application.Presentations.Count = 0 Then
        MsgBox "Si us plau, crea o obre una presentació abans d'executar aquesta macro.", vbExclamation, "No s'ha trobat cap presentació"
        Exit Sub
    End If
    
    ' Estableix l'objecte a la presentació actualment activa
    Set oPres = Application.ActivePresentation
    
    ' Obtenir l'índex per afegir la primera diapositiva al final
    slideIndex = oPres.Slides.Count + 1

    ' --- Diapositiva 1: Títol del Projecte ---
    Call AddTitleSlide(oPres, slideIndex, _
                       "Projecte Smart_Office: Disseny i Implementació d'un Sistema d'Automatització Integral per a Edificis", _
                       "Autor: Tòfol Tous" & vbCrLf & "Projecte d'Automatització i Robòtica Industrial")
    slideIndex = slideIndex + 1    ' --- Diapositiva 2: Introducció i Objectius ---
    sTitol = "Introducció i Objectius"
    sContingut = "La Necessitat:" & vbCrLf & _
                "Els edificis d'oficines moderns necessiten sistemes intel·ligents que optimitzin el consum energètic i millorin el confort dels usuaris, tot mantenint-se econòmicament viables." & vbCrLf & vbCrLf & _
                "Objectiu Principal:" & vbCrLf & _
                "Desenvolupar un sistema d'automatització integral que converteixi un edifici convencional en un edifici intel·ligent, centrat en:" & vbCrLf & _
                "   • Control automàtic de la il·luminació adaptativa" & vbCrLf & _
                "   • Gestió intel·ligent de persianes segons condicions ambientals" & vbCrLf & _
                "   • Sistema de climatització amb control PID dual" & vbCrLf & vbCrLf & _
                "Aspecte Innovador:" & vbCrLf & _
                "Integració de tecnologies industrials (PLC/HMI) amb eines modernes de IoT i contenidors, creant una solució robusta i econòmica."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1

    ' --- Diapositiva 3: Arquitectura General ---
    sTitol = "Arquitectura General del Sistema"
    sContingut = "Aquesta diapositiva mostra la interconnexió de tots els elements del sistema, des del món físic (sensors) fins al núvol (Cloud)." & vbCrLf & vbCrLf & _
                "CONSELL: Inseriu aquí el 'Diagrama de Connexió Física' (Figura 5 del PDF) i expliqueu el flux de dades pas a pas."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1

    ' --- Diapositiva 4: Infraestructura de Software ---
    sTitol = "Infraestructura de Software i Protocols"
    sContingut = "Entorn d'Execució: Màquina Virtual Linux (Debian 12) sobre Oracle VirtualBox." & vbCrLf & _
                "Orquestració: Ús de Docker Compose per gestionar contenidors aïllats (Node-RED, InfluxDB, Grafana)." & vbCrLf & _
                "Protocols de Comunicació:" & vbCrLf & _
                "   • PLC <-> Servidor: Protocol SNAP7 sobre Ethernet, amb NetToPLCSim com a pont." & vbCrLf & _
                "   • HMI <-> Servidor: WebSockets per a comunicació en temps real." & vbCrLf & _
                "   • IoT <-> Servidor: Peticions HTTP GET a l'API del dispositiu Shelly."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1

    ' --- Diapositiva 5: Cas Pràctic 1: Persianes ---
    sTitol = "Cas Pràctic 1: Control de Persianes amb Intel·ligència Externa"
    sContingut = "El Repte: Aconseguir que les persianes reaccionin a l'entorn real." & vbCrLf & _
                "Solució:" & vbCrLf & _
                "   1. Node-RED consulta APIs de meteorologia (OpenWeatherMap) i radiació solar." & vbCrLf & _
                "   2. Un bloc de funció en JavaScript processa el JSON de la resposta i tradueix les dades." & vbCrLf & _
                "   3. Les dades netes (estat del cel, W/m²) s'envien al PLC via SNAP7." & vbCrLf & _
                "   4. El PLC executa la lògica de control automàtic que decideix la posició òptima."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1

    ' --- Diapositiva 6: Cas Pràctic 2: Clima PID ---
    sTitol = "Cas Pràctic 2: Control Climàtic de Precisió amb PID Dual"
    sContingut = "El Repte: Mantenir una temperatura estable evitant oscil·lacions." & vbCrLf & _
                "Solució:" & vbCrLf & _
                "   • Estratègia PID Dual: Dues instàncies de PID_Compact a TIA Portal (una per fred, una per calor)." & vbCrLf & _
                "   • Habilitació Selectiva: La lògica del PLC activa només el PID necessari en cada moment." & vbCrLf & _
                "   • Zona Morta (Deadband): S'implementa una banda de no-actuació per evitar funcionament constant al voltant del setpoint." & vbCrLf & _
                "   • Simulació i Sintonització: Ús de Factory I/O per simular el sensor i TIA Portal per sintonitzar els paràmetres PID."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1
    
    ' --- Diapositiva 7: Monitorització Energètica ---
    sTitol = "Gestió del Cicle de Vida de la Dada Energètica"
    sContingut = "Pipeline de dades:" & vbCrLf & _
                "   1. Captura (Edge): Pinces Shelly EM mesuren el consum elèctric." & vbCrLf & _
                "   2. Recollida (Middleware): Node-RED obté les dades via HTTP i les processa." & vbCrLf & _
                "   3. Emmagatzematge (Base de Dades): S'escriuen a InfluxDB (Base de Dades de Sèries Temporals)." & vbCrLf & _
                "   4. Visualització (Frontend): Grafana es connecta a InfluxDB per crear dashboards interactius."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1

    ' --- Diapositiva 8: Reptes Tècnics ---
    sTitol = "Reptes Tècnics i Solucions Implementades"
    sContingut = "Repte 1: Comunicació Node-RED <-> PLC Simulat." & vbCrLf & _
                "   Solució: Ús del software intermediari NetToPLCSim com a pont SNAP7." & vbCrLf & vbCrLf & _
                "Repte 2: Gestió de múltiples serveis de software de manera aïllada." & vbCrLf & _
                "   Solució: Infraestructura definida com a codi amb Docker i Docker Compose." & vbCrLf & vbCrLf & _
                "Repte 3: Evitar transicions brusques en climatització." & vbCrLf & _
                "   Solució: Implementació d'un temporitzador de retard al PLC."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1
    
    ' --- Diapositiva 9: Conclusions ---
    sTitol = "Conclusions i Futures Línies de Treball"
    sContingut = "Conclusions:" & vbCrLf & _
                "   • S'ha validat la creació d'un sistema BMS potent combinant tecnologia industrial (PLC) amb software open-source." & vbCrLf & _
                "   • L'arquitectura dissenyada és modular, escalable i flexible." & vbCrLf & vbCrLf & _
                "Futures Línies de Treball:" & vbCrLf & _
                "   • Implementació de Redundància i Alta Disponibilitat (HA) per a entorns de producció." & vbCrLf & _
                "   • Desenvolupament de models de Machine Learning per a manteniment predictiu." & vbCrLf & _
                "   • Creació de passarel·les a protocols estàndard com BACnet o Modbus."
    Call AddContentSlide(oPres, slideIndex, sTitol, sContingut)
    slideIndex = slideIndex + 1
    
    ' --- Diapositiva 10: Preguntes (Disseny especial) ---
    Call AddTitleSlide(oPres, slideIndex, "Gràcies per la Vostra Atenció", "Preguntes?")
    
    ' Neteja d'objectes
    Set oPres = Nothing

    MsgBox "S'han afegit 10 diapositives a la presentació activa.", vbInformation
End Sub
