package main

import (
	"compress/gzip"
	"encoding/csv"
	"fmt"
	"io/ioutil"
	"log"
	"math/big"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/common"

	"github.com/shopspring/decimal"
)

func readCsv(filePath string, compressed bool) [][]string {
	f, err := os.Open(filePath)
	if err != nil {
		log.Fatal("Unable to read input file "+filePath, err)
	}
	defer f.Close()
	var csvReader *csv.Reader
	if compressed {
		gr, err := gzip.NewReader(f)
		if err != nil {
			log.Fatal(err)
		}
		defer gr.Close()
		csvReader = csv.NewReader(gr)
	} else {
		csvReader = csv.NewReader(f)
	}
	records, err := csvReader.ReadAll()
	if err != nil {
		log.Fatal("Unable to parse file as CSV for "+filePath, err)
	}

	return records[1:]
}

var (
	TRANSFER        = common.HexToHash("0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
	DELEGATECHANGED = common.HexToHash("0x3134e8a2e6d97e929a7e54011ea5485d7d196dd5f0ba4d4ef95803e8e3fc257f")
	GASDAO_TOKEN    = common.HexToAddress("0x6Bba316c48b49BD1eAc44573c5c871ff02958469")
)

const (
	// half-life of 1 week
	alpha = 0.9999828089974554711736567733551404044961683376730844584685269050
)

type Tx struct {
	Hash        common.Hash
	From        common.Address
	To          common.Address
	Cost        float64
	BlockNumber int
	BlockTime   int
	Index       int
	LenLogs     int
}

type Log struct {
	Address  common.Address
	Topic0   common.Hash
	Data     string
	Hash     common.Hash
	LogIndex int
	Topics   string
}

func loadTxs(txsPath string) []*Tx {
	// load txs
	txFiles, err := ioutil.ReadDir(txsPath)
	if err != nil {
		log.Fatal(err)
	}
	// txFiles = txFiles[:1]
	txs := make([]*Tx, 0, len(txFiles))

	for _, f := range txFiles {
		txsi := readCsv("data_eth/gasdao_txs/"+f.Name(), true)
		for _, txi := range txsi {
			cost, _ := strconv.ParseFloat(txi[4], 64)
			blockNumber, _ := strconv.Atoi(txi[5])
			blockTime, _ := strconv.Atoi(txi[6])
			index, _ := strconv.Atoi(txi[7])
			lenLogs, _ := strconv.Atoi(txi[8])
			txs = append(txs, &Tx{
				Hash:        common.HexToHash(txi[1]),
				From:        common.HexToAddress(txi[2]),
				To:          common.HexToAddress(txi[3]),
				Cost:        cost,
				BlockNumber: blockNumber,
				BlockTime:   blockTime,
				Index:       index,
				LenLogs:     lenLogs,
			})
		}
	}
	return txs
}

func loadLogs(logsPath string) []*Log {
	// load logs
	logFiles, err := ioutil.ReadDir(logsPath)
	if err != nil {
		log.Fatal(err)
	}
	// logFiles = logFiles[:1]
	logs := make([]*Log, 0, len(logFiles))

	for _, f := range logFiles {
		logsi := readCsv("data_eth/gasdao_logs/"+f.Name(), true)
		for _, logi := range logsi {
			logIndex, _ := strconv.Atoi(logi[5])
			logs = append(logs, &Log{
				Address:  common.HexToAddress(logi[1]),
				Topic0:   common.HexToHash(logi[2]),
				Data:     logi[3],
				Hash:     common.HexToHash(logi[4]),
				LogIndex: logIndex,
				Topics:   logi[6],
			})
		}
	}
	return logs
}

func main() {
	balanceOf := make(map[common.Address]*big.Int)
	delegated := make(map[common.Address]bool)
	weightedDelegation := make(map[common.Address]float64)
	spent := make(map[common.Address]float64)
	txCt := make(map[common.Address]int)
	spentWeighted := make(map[common.Address]float64)
	rewards := make(map[common.Address]float64)

	logs := loadLogs("data_eth/gasdao_logs")
	fmt.Println(logs[0])

	txs := loadTxs("data_eth/gasdao_txs")
	fmt.Println(txs[0])

	// make a map from tx hash to logs
	txHashToLogs := make(map[common.Hash][]*Log)
	for _, log := range logs {
		if _, ok := txHashToLogs[log.Hash]; !ok {
			txHashToLogs[log.Hash] = make([]*Log, 0)
		}
		txHashToLogs[log.Hash] = append(txHashToLogs[log.Hash], log)
	}

	fmt.Println(len(txHashToLogs))

	// sort transactions by block and tx index
	sort.Slice(txs, func(i, j int) bool {
		if txs[i].BlockNumber < txs[j].BlockNumber {
			return true
		} else if txs[i].BlockNumber > txs[j].BlockNumber {
			return false
		}
		return txs[i].Index < txs[j].Index
	})

	lastUpdatedBlockNumber := 0
	lastUpdatedBlockTime := 0
	blockNumber := txs[0].BlockNumber
	lastReward := 13929167

	for _, tx := range txs {
		logs := txHashToLogs[tx.Hash]

		// update balanceOf and delegated hash maps
		for _, log := range logs {
			if log.Address == GASDAO_TOKEN {
				if log.Topic0 == TRANSFER {
					amount := new(big.Int).SetBytes(common.FromHex(log.Data))
					topics := strings.Split(log.Topics, "0x")[1:]
					from := common.HexToAddress("0x" + topics[0][24:])
					to := common.HexToAddress("0x" + topics[1][24:])
					if _, ok := balanceOf[to]; !ok {
						balanceOf[to] = big.NewInt(0)
					}
					balanceOf[to] = new(big.Int).Add(balanceOf[to], amount)
					if from != common.HexToAddress("") {
						balanceOf[from] = new(big.Int).Sub(balanceOf[from], amount)
					}
				} else if log.Topic0 == DELEGATECHANGED {
					delegator := common.HexToAddress(strings.Split(log.Topics, "0x")[1][24:])
					delegated[delegator] = true
					if _, ok := balanceOf[delegator]; !ok {
						balanceOf[delegator] = big.NewInt(0)
					}
				}
			}
		}

		// new block
		if tx.BlockNumber >= 13929167 {
			if tx.BlockNumber > blockNumber {
				for k, _ := range delegated {
					balanceFloat, _ := decimal.NewFromBigInt(balanceOf[k], -int32(18)).Float64()
					newWeight := 0.0
					if delegated[k] {
						newWeight = balanceFloat
					}
					if _, ok := weightedDelegation[k]; !ok {
						weightedDelegation[k] = 0.0
					}
					weightedDelegation[k] = weightedDelegation[k]*(alpha) + newWeight*(1-alpha)
				}
			}
			if tx.BlockNumber-lastReward >= 5760 {
				fmt.Println("Distributing rewards", "block number", tx.BlockNumber, "last reward", lastReward)
				totalSpent := 0.0
				for k := range delegated {
					if _, ok := rewards[k]; !ok {
						rewards[k] = 0
					}
				}
				for _, v := range spentWeighted {
					totalSpent += v
				}
				for k, v := range spentWeighted {
					rewards[k] += 500000000 * v / totalSpent
				}
				spentWeighted = make(map[common.Address]float64)
				lastReward = tx.BlockNumber
				lastUpdatedBlockNumber = tx.BlockNumber
				lastUpdatedBlockTime = tx.BlockTime
			}
			if val, ok := weightedDelegation[tx.From]; ok {
				spentWeighted[tx.From] += val * tx.Cost
				spent[tx.From] += tx.Cost
				txCt[tx.From]++
			}
		}

		blockNumber = tx.BlockNumber
	}

	total := 0.0
	for _, v := range spent {
		total += v
	}

	ct := 0
	for _, v := range txCt {
		ct += v
	}

	fmt.Println("Total spent by gas holders", total, "#txs", ct)
	fmt.Println(len(balanceOf))

	unique := 0
	for _, v := range balanceOf {
		if v.Cmp(big.NewInt(0)) > 0 {
			unique++
		}
	}

	fmt.Println("Unique", unique)
	fmt.Println("rewards", len(rewards))

	f, err := os.OpenFile("rewards.csv", os.O_TRUNC|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatal(err)
	}
	w := csv.NewWriter(f)

	w.Write([]string{
		"address",
		"reward",
		"eth",
		"count",
		"blockNumber",
		"blockTime",
	})

	for k, v := range rewards {
		w.Write([]string{
			k.Hex(),
			fmt.Sprintf("%.8f", v),
			fmt.Sprintf("%.8f", spent[k]),
			fmt.Sprintf("%d", txCt[k]),
			fmt.Sprintf("%d", lastUpdatedBlockNumber),
			fmt.Sprintf("%d", lastUpdatedBlockTime),
		})
	}
	w.Flush()
	f.Close()
}
