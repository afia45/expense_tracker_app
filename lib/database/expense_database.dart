import 'package:expense_tracker_app/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';




class ExpenseDatabase extends ChangeNotifier{
  static late Isar isar;
  List<Expense> _allExpenses = [];

  /*Setup */
  //Initialise db
  static Future<void> initialise() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([ExpenseSchema], directory: dir.path);
  }


  /*Getters */
  List<Expense> get allExpense => _allExpenses;


  /*Operators */
  //create - add a new expense

  Future<void> createNewExpense(Expense newExpense) async {
    //add to db
    await isar.writeTxn(() => isar.expenses.put(newExpense));
    //re read from db
    await readExpenses();
  }

  // read - expenses from db
  Future<void> readExpenses() async {
    //fetch all existing expenses from db
    List<Expense> fetchedExpenses = await isar.expenses.where().findAll();

    //give to local expense list
    _allExpenses.clear();
    _allExpenses.addAll(fetchedExpenses);

    //update ui
    notifyListeners();
  }

  // update - edit an expense in db
  Future<void> updateExpense(int id, Expense updatedExpense) async{
    //make sure new expense has same id as existing one
    updatedExpense.id = id;

    //update in db
    await isar.writeTxn(()=> isar.expenses.put(updatedExpense));

    //re-reas from db
    await readExpenses();
  }

  // delete - an expense
  Future<void> deleteExpense(int id) async {
    //delete from db
    await isar.writeTxn(() => isar.expenses.delete(id));

    //re read from db
    await readExpenses();
  }

  /*Helper */
  //calc total exp for each month

  Future<Map<String, double>> calculateMonthlyTotals() async{
    // ensure the expenses are read from the db
    await readExpenses();

    //create a map to keep track of total exp per month
    Map<String, double> monthlyTotals = {};
      // iterate over all expenses
      for (var expense in _allExpenses){
        //extract yr and month from the date of the expense
        //int month = expense.date.month;
        String yearMonth = '${expense.date.year}-${expense.date.year}';

        //if the yr-month is not in the map yet then init to 0
        if(!monthlyTotals.containsKey(yearMonth)){
          monthlyTotals[yearMonth] = 0;
        }

        //add the exp amnt to the total for the month
        monthlyTotals[yearMonth] = monthlyTotals[yearMonth]!+expense.amount;
      }

    return monthlyTotals;
  }

  //calc current month exp
  Future<double> calculateCurrentMonthTotal() async{
    //ensure expenses are read from db first
    await readExpenses();

    //get current month,yr
    int currentMonth = DateTime.now().month;
    int currentYear = DateTime.now().year;

    //filter the expenses to include only those for this month this year
    List<Expense> currentMonthExpenses = _allExpenses.where((expense){
      return expense.date.month == currentMonth && 
      expense.date.year == currentYear;
    }).toList();

    //calc total amnt for the current month
    double total = currentMonthExpenses.fold(0, (sum, expense)=> sum+expense.amount);

    return total;
  }

  //get start month----------------
  int getStartMonth(){
    if(_allExpenses.isEmpty) {
      return DateTime.now().month; //default to current month is no expenses are recorded
    }

    // sort expenses by date to find the earliest
    _allExpenses.sort((a,b)=> a.date.compareTo(b.date),);

    return _allExpenses.first.date.month;

  }

  // get start year-----------
  int getStartYear(){
    if(_allExpenses.isEmpty) {
      return DateTime.now().year; //default to current month is no expenses are recorded
    }

    // sort expenses by date to find the earliest
    _allExpenses.sort((a,b)=> a.date.compareTo(b.date),);

    return _allExpenses.first.date.year;
  }
}
