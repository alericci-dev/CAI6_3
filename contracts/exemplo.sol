// SPDX-License-Identifier: MI
pragma solidity >=0.7.0 < 0.9.0;

contract Subasta {
    address payable public owner;
    uint256 public endDate;
    uint256 public endDateEntrega;
    uint256 public mercado;
    uint256 public numPujadores;
    uint256 private constant MAX_PUJADORES = 4;
    uint256 private constant FIANZA_PORCENTAJE = 10;

    constructor () {
        owner = payable(msg.sender);
        numPujadores = 0;
    }

    struct Puja {
        address payable participante;
        uint256 fecha;
        uint256 tasa;
        uint256 fianza;
    }
    
    Puja[] public pujasArray;
    address payable[] public ganadores;
    bool public subastaFinalizada;

    event Message(string msg);
    event Valores(string msg, uint256 variable);

    function valorMercado(uint valor) public {
        require(msg.sender == owner, "Solo el owner puede modificar el valor de mercado");
        mercado = valor;
    }

    function fechaFin(uint fin) public {
        require(msg.sender == owner, "Solo el owner puede modificar la fecha de fin de la subasta");
        endDate = block.timestamp + fin * 86400;
    }

    function tasa() public payable {
        require(numPujadores < MAX_PUJADORES, "Se ha alcanzado el límite máximo de pujadores");
        require(msg.value > 0, "La tasa debe ser positiva");
        require(block.timestamp < endDate, "La subasta ha finalizado");
        
        uint256 fianza = msg.value * FIANZA_PORCENTAJE / 100;
        pujasArray.push(Puja(payable(msg.sender), block.timestamp, msg.value, fianza));
        numPujadores++;

        emit Message("Tasa abonada");
    }

    function finalizarSubasta() public {
        require(msg.sender == owner, "Solo el owner puede finalizar la subasta");
        require(!subastaFinalizada, "La subasta ya ha sido finalizada");
        require(block.timestamp >= endDate, "La subasta no ha finalizado");

        uint indexGanador = encontrarGanador();
        ganadores.push(pujasArray[indexGanador].participante);
        subastaFinalizada = true;

        for (uint256 i = 0; i < pujasArray.length; i++) {
            if (i != indexGanador) {
                pujasArray[i].participante.transfer(pujasArray[i].tasa);
            }
        }
    }

    function encontrarGanador() private view returns (uint256) {
        uint256 tasaGanadora = mercado;
        uint256 indexGanador = 0;

        for (uint256 i = 0; i < pujasArray.length; i++) {
            if (pujasArray[i].tasa < tasaGanadora) {
                tasaGanadora = pujasArray[i].tasa;
                indexGanador = i;
            }
        }

        return indexGanador;
    }

    function encontrarSegundoGanador() private view returns (uint256) {
        uint256 tasaGanadora = mercado;
        uint256 segundaTasaGanadora = mercado;
        uint256 indexSegundoGanador = 0;

        for (uint256 i = 0; i < pujasArray.length; i++) {
            if (pujasArray[i].tasa < tasaGanadora) {
                segundaTasaGanadora = tasaGanadora;
                tasaGanadora = pujasArray[i].tasa;
                indexSegundoGanador = i;
            } else if (pujasArray[i].tasa < segundaTasaGanadora && pujasArray[i].tasa != tasaGanadora) {
                segundaTasaGanadora = pujasArray[i].tasa;
                indexSegundoGanador = i;
            }
        }

        return indexSegundoGanador;
    }

    function fechaFinEntrega(uint fin) public {
        require(msg.sender == owner, "Solo el owner puede modificar la fecha de fin de entrega");
        endDateEntrega = block.timestamp + fin * 86400;
    }

    function entregaMedicamentos() public payable {
        require(ganadores.length >= 2, "No se ha seleccionado el segundo ganador");
        require(msg.sender == ganadores[0], "No es el primer participante ganador");
        require(block.timestamp < endDateEntrega, "La fecha de entrega ha expirado");
        require(msg.value == pujasArray[encontrarSegundoGanador()].fianza, "El ingreso no corresponde a la fianza del segundo ganador");

        owner.transfer(pujasArray[encontrarSegundoGanador()].fianza);
        ganadores[1].transfer(ganadores[0].balance);
    }
}
