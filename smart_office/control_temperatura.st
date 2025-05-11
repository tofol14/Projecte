// BLOC 1: INICIALITZACIÓ I DEFINICIÓ DE VARIABLES
VAR_INPUT
    SetPointNodeRED : Real;  // Setpoint rebut de Node-RED
    sensor_temp_jefe : Int;  // Entrada del sensor de Factory IO (%IW40)
    temperatura_DB : "temperatura_cap_DB";  // Referència al DB de temperatura
END_VAR

VAR_OUTPUT
    TemperaturaNodeRED : Real;  // Temperatura en graus per Node-RED
END_VAR

STATIC
    // Constants del sistema
    TEMP_MIN : Real := 0.0;           // Temperatura mínima permesa (canviat de 15.0)
    TEMP_MAX : Real := 50.0;          // Temperatura màxima permesa (canviat de 30.0)
    ZONA_MORTA : Real := 0.3;         // Marge de zona morta pel control
    HISTERESI : Real := 1.2;          // Factor d'histèresi
    TEMPS_MINIM_CANVI : Time := T#180S; // Temps mínim entre canvis de mode
    TAXA_ESCALFAMENT : Real := 0.1;    // Taxa d'escalfament simulada
    TAXA_REFREDAMENT : Real := 0.05;   // Taxa de refredament simulada
    
    // Variables de control i estat
    PrimeraExecucio : Bool := TRUE;   // Flag de primera execució
    EstemEnZonaMorta : Bool;          // Control d'histèresi
    ControlActiu : Bool;              // Estat del sistema
    ModeFred : Bool;                  // Mode refrigeració actiu
    ModeCalent : Bool;                // Mode calefacció actiu
    ModeActual : String;              // Mode actual en text
    
    // Variables de temperatura i sensors
    TemperaturaSimulada : Real;       // Temperatura simulada del sistema
    UltimaTemperaturaReal : Real;     // Última lectura vàlida
    TemperaturaReal : Real;           // Temperatura actual
    TemperaturaEscalada : Real;       // Temperatura processada
    ValorSensor : Real;               // Valor raw del sensor
    Valor_Raw_Sensor : Int;           // Valor enter del sensor
    
    // Variables de temps i simulació
    TempsActual : Time;               // Temps actual
    TempsAnterior : Time;             // Temps anterior
    DeltaTemps : Real;                // Interval de temps
    ProporcioSimulada : Real;         // Proporció per simulació
    ValorSensorSimulat : Int;         // Valor simulat
    
    // Variables de sortida i control
    SortidaPID : Real;                // Sortida del controlador PID
    SortidaEscalada : Real;           // Sortida escalada (0-100%)
    
    // Variables HMI/Monitorització
    HMI_TemperaturaActual : Real;     // Temperatura actual per HMI
    HMI_SetPoint : Real;              // SetPoint actual per HMI
    HMI_ModeActual : String;          // Mode de funcionament per HMI
    HMI_PercentatgeSortida : Real;    // Percentatge sortida per HMI

{REGION 'Declaració de variables PID'}
VAR_INPUT
    EN : Bool;              // Habilitació del PID
    Setpoint : Real;        // Valor desitjat de temperatura
    Input : Real;           // Valor actual de temperatura
END_VAR

VAR_OUTPUT
    Output : Real;          // Sortida del controlador PID
END_VAR

// 1. PROCESSAMENT DEL SENSOR DE TEMPERATURA
// Inicialització de variables de simulació
IF #PrimeraExecucio THEN
    #PrimeraExecucio := FALSE;
    #TemperaturaSimulada := #TEMP_MIN;
    #UltimaTemperaturaReal := #TEMP_MIN;
    #TemperaturaEscalada := #TEMP_MIN;
    #TempsAnterior := T#0MS;
END_IF;

// 2. CONTROL PRINCIPAL ON/OFF
IF NOT #ClimaOn THEN
    // Sistema desactivat - Reset de variables
    #ControlActiu := FALSE;
    #SortidaPID := 0.0;
    #SortidaEscalada := 0.0;
    #ModeFred := FALSE;
    #ModeCalent := FALSE;
    #ModeActual := 'OFF';
    // Mantenim la última temperatura quan està apagat
    #TemperaturaEscalada := #TemperaturaSimulada;
ELSE
    #ControlActiu := TRUE;
END_IF;

// 3. ACTUALITZACIÓ DEL TEMPS I SIMULACIÓ
// Actualitzar temps per la simulació utilitzant TON
#TimerSimulacio(IN := TRUE,
                PT := T#1S);  // Actualitzem cada segon

IF #TimerSimulacio.Q THEN
    #TempsActual := #TimerSimulacio.ET;
    
    // Calcular delta de temps (en segons)
    IF #TempsAnterior = T#0MS THEN
        #DeltaTemps := 0.1;  // Valor inicial per evitar pics
    ELSE
        #DeltaTemps := DINT_TO_REAL(TIME_TO_DINT(#TempsActual - #TempsAnterior)) / 1000.0;
    END_IF;
    
    #TempsAnterior := #TempsActual;
    #TimerSimulacio(IN := FALSE,
                    PT := T#1S);  // Reiniciar el timer
END_IF;

// Processar valor del sensor abans de la simulació
#ValorSensor := INT_TO_REAL(#sensor_temp_jefe);
#Valor_Raw_Sensor := #sensor_temp_jefe;

// Normalització i escalat del sensor actual
#Proporcio := #ValorSensor / 27648.0;
#TemperaturaReal := #Proporcio * (#TEMP_MAX - #TEMP_MIN) + #TEMP_MIN;
#TemperaturaEscalada := #TemperaturaReal;  // Utilitzem la temperatura real en lloc de la simulada

// Assignar al DB de temperatura utilitzant la referència
#temperatura_DB.TemperaturaEscalada := #TemperaturaEscalada;

// Validació del SetPoint
IF #SetPointNodeRED < #TEMP_MIN THEN
    #SetPointNodeRED := #TEMP_MIN;
ELSIF #SetPointNodeRED > #TEMP_MAX THEN
    #SetPointNodeRED := #TEMP_MAX;
END_IF;

// Debug dels valors - Actualitzem sempre
#proporcio_debug := #Proporcio;
#temp_real_debug := #TemperaturaReal;
#setpoint_debug := #SetPointNodeRED;
#temp_entrada_pid := #TemperaturaEscalada;
#setpoint_entrada_pid := #SetPointNodeRED;

// Simulació del comportament tèrmic sempre activa
IF #ControlActiu THEN
    IF #ModeFred THEN
        // Mode refrigeració - La sortida del PID refreda
        #TemperaturaSimulada := #TemperaturaSimulada - (#SortidaEscalada * #TAXA_ESCALFAMENT * #DeltaTemps);
    ELSE
        // Mode calefacció - La sortida del PID escalfa
        #TemperaturaSimulada := #TemperaturaSimulada + (#SortidaEscalada * #TAXA_ESCALFAMENT * #DeltaTemps);
    END_IF;
    
    // Simular pèrdua natural de temperatura
    IF #TemperaturaSimulada > #TEMP_MIN THEN
        #TemperaturaSimulada := #TemperaturaSimulada - (#TAXA_REFREDAMENT * #DeltaTemps);
    END_IF;
    
    // Limitar la temperatura simulada
    IF #TemperaturaSimulada < #TEMP_MIN THEN
        #TemperaturaSimulada := #TEMP_MIN;
    ELSIF #TemperaturaSimulada > #TEMP_MAX THEN
        #TemperaturaSimulada := #TEMP_MAX;
    END_IF;
    
    // Actualitzar temperatura escalada amb la simulada
    #TemperaturaEscalada := #TemperaturaSimulada;
    
    // Convertir temperatura simulada a format sensor (0-27648)
    #ProporcioSimulada := (#TemperaturaSimulada - #TEMP_MIN) / (#TEMP_MAX - #TEMP_MIN);
    #ValorSensorSimulat := REAL_TO_INT(#ProporcioSimulada * 27648.0);
    
    // Assignar al tag del sensor
    "sensor_temp_jefe" := #ValorSensorSimulat;
END_IF;

// Debug dels valors - Actualitzem sempre
#proporcio_debug := #ProporcioSimulada;
#temp_real_debug := #TemperaturaSimulada;
#setpoint_debug := #SetPointNodeRED;
#temp_entrada_pid := #TemperaturaEscalada;
#setpoint_entrada_pid := #SetPointNodeRED;

// 3. GESTIÓ DE MODES AMB TEMPORITZACIÓ
IF #ControlActiu THEN
    // Control de temps mínim entre canvis
    #TimerCanviMode(IN := #BotoFred OR #BotoCalent,
                    PT := #TEMPS_MINIM_CANVI);
    
    // Canvi de mode amb temporització
    IF #TimerCanviMode.Q THEN
        IF #BotoFred AND NOT #BotoCalent AND NOT #ModeFred THEN
            // Activació mode fred
            #ModeFred := TRUE;
            #ModeCalent := FALSE;
            #ModeActual := 'Fred';
        ELSIF #BotoCalent AND NOT #BotoFred AND NOT #ModeCalent THEN
            // Activació mode calent
            #ModeFred := FALSE;
            #ModeCalent := TRUE;
            #ModeActual := 'Calent';
        END_IF;
    END_IF;
    
    // 4. CONTROL PID I SORTIDA
    IF #ClimaOn THEN
        // Configuració del PID
        "Control_temperatura_oficina_cap"(
            EN := #ClimaOn,
            Setpoint := #SetPointNodeRED,
            Input := #TemperaturaEscalada
        );
        
        // Execució del PID si estem fora de la zona morta
        IF NOT #EstemEnZonaMorta THEN
            #SortidaPID := "Control_temperatura_oficina_cap".Output;
            // Gestió mode fred
            IF #ModeFred THEN
                #SortidaPID := -#SortidaPID;
            END_IF;
            
            // Limitació de la sortida amb més granularitat
            IF #SortidaPID < 0.0 THEN
                #SortidaEscalada := 0.0;
            ELSIF #SortidaPID > 100.0 THEN
                #SortidaEscalada := 100.0;
            ELSE
                #SortidaEscalada := #SortidaPID;
            END_IF;
        END_IF;
    ELSE
        "Control_temperatura_oficina_cap"(EN := FALSE);
    END_IF;
END_IF;

// BLOC 5: PROCESSAMENT DE SORTIDES
// Convertir temperatura simulada a format sensor
#ProporcioSimulada := (#TemperaturaSimulada - #TEMP_MIN) / (#TEMP_MAX - #TEMP_MIN);
#ValorSensorSimulat := REAL_TO_INT(#ProporcioSimulada * 27648.0);

// Assignar al tag del sensor (simulació)
"sensor_temp_jefe" := #ValorSensorSimulat;

// Actualitzar sortides físiques
#refredament := #ControlActiu AND #ModeFred AND (#SortidaEscalada > 10.0);
#calefaccio := #ControlActiu AND #ModeCalent AND (#SortidaEscalada > 10.0);

// BLOC 6: DIAGNÒSTIC I MONITORITZACIÓ
// Variables per monitorització
#HMI_TemperaturaActual := #TemperaturaSimulada;
#HMI_SetPoint := #SetPointNodeRED;
#HMI_ModeActual := #ModeActual;
#HMI_PercentatgeSortida := #SortidaEscalada;

// Actualitzar temperatura per Node-RED
#Temperatura := #TemperaturaEscalada;

