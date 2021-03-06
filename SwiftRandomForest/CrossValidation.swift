//MIT License
//
//Copyright (c) 2017 Lucas Farris
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

import UIKit

protocol ClassifierAlgorithm {
    associatedtype NumericType:Numeric
    func runClassifier(trainDataset:MatrixReference<NumericType>, testDataset:MatrixReference<NumericType>, completion: @escaping (Array<NumericType>)->())
}

class CrossValidation<T:Numeric, U:ClassifierAlgorithm>: NSObject where U.NumericType == T {
    
    typealias NumericType = T
    
    private var folds:Int
    private var algorithm:U
    private var trainSet:MatrixReference<T>?
    
    init(algorithm:U, folds:Int) {
        self.folds = folds
        self.algorithm = algorithm
    }
    
    public func evaluateAlgorithm(dataset:Matrix<T>) {
        let folds:Array<MatrixReference<T>> = crossValidationSplit(dataset: dataset, folds: self.folds)
        self.evaluateFold(0, dataset:dataset, folds: folds)
    }
    
    
    private func evaluateFold(_ foldIndex:Int, dataset:Matrix<T>, folds:Array<MatrixReference<T>>) {
        if foldIndex == folds.count {
            return
        }
        var allData = folds
        let testSet:MatrixReference<T> = allData.remove(at: foldIndex)
        self.trainSet = MatrixReference<T>.init(matrix: dataset)
        
        if let safeTrainSet = self.trainSet {
            for fold:MatrixReference<T> in allData {
                safeTrainSet.append(otherMatrix: fold)
            }
            
            self.algorithm.runClassifier(trainDataset: safeTrainSet, testDataset: testSet, completion: { (predicted:Array<T>) in
                let actual = folds[foldIndex].outputs
                let accuracy = self.kappaMetric(actual: actual, predicted: predicted)
                print ("Fold \(foldIndex) had score \(accuracy)")
                
                self.evaluateFold(foldIndex+1, dataset: dataset, folds: folds)
            })
        }
    }
    
    private func test(actual:Array<T>, predicted:Array<T>) -> Double {
        let correct = zip(actual, predicted).reduce(0){ (a: Int, element) in
            var accumulator = a
            if element.0 == element.1 {
                accumulator += 1
            }
            return accumulator
        }
        return Double(correct)/Double(actual.count)
    }
    
    private func kappaMetric(actual:Array<T>, predicted:Array<T>) -> Double {
        var truePositive = 0.0, falsePositive = 0.0, falseNegative = 0.0, trueNegative = 0.0
        
        let falseValue = T.parse(text: "\(0)")
        let trueValue = T.parse(text: "\(1)")
        
        for i in 0..<actual.count {
            if actual[i] == falseValue &&  predicted[i] == falseValue {
                falseNegative += 1
            } else if actual[i] == falseValue &&  predicted[i] == trueValue {
                falsePositive = 1
            } else if actual[i] == trueValue &&  predicted[i] == trueValue {
                truePositive += 1
            } else {
                trueNegative += 1
            }
        }
        let a:Double=truePositive, b:Double=trueNegative, c:Double=falsePositive, d:Double=falseNegative
        
        let p0:Double = (a+d)/(a+b+c+d)
        let marginalA:Double = (a+b)*(a+c)/(a+b+c+d)
        let marginalB:Double = (c+b)*(c+d)/(a+b+c+d)
        let pE:Double = (marginalA+marginalB)/(a+b+c+d)
        let k:Double = (p0-pE)/(1-pE)
        return k
    }
    
    private func accuracyMetric(actual:Array<T>, predicted:Array<T>) -> Double {
        var correct = 0
        for i in 0..<actual.count {
            if actual[i] == predicted[i] {
                correct += 1
            }
        }
        return Double(correct)/Double(actual.count)
    }
    
    
    private func crossValidationSplit(dataset:Matrix<T>, folds:Int) -> Array<MatrixReference<T>> {
        var datasetSplit:Array<MatrixReference<T>> = []
        let datasetCopy:MatrixReference<T> = MatrixReference<T>.init(matrix: dataset)
        datasetCopy.fill(dataset.rows)
        let foldSize = Int(dataset.rows/folds)
        for _ in 0..<folds {
            let fold:MatrixReference<T> = MatrixReference<T>.init(matrixReference: datasetCopy, count: foldSize)
            while fold.count < foldSize {
                let index = Int(arc4random_uniform(UInt32(datasetCopy.count)))
                fold.append(index:datasetCopy.remove(index))
            }
            datasetSplit.append(fold)
        }
        return datasetSplit
    }
    
}
