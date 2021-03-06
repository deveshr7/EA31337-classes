//+------------------------------------------------------------------+
//|                                                EA31337 framework |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/*
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

// Prevents processing this includes file for the second time.
#ifndef SERIALIZER_CSV_MQH
#define SERIALIZER_CSV_MQH

// Includes.
#include "Dict.mqh"
#include "DictObject.mqh"
#include "DictStruct.mqh"
#include "Matrix.mqh"
#include "Object.mqh"
#include "Serializer.mqh"
#include "SerializerNode.mqh"

struct CsvTitle {
  int column_index;
  string title;

  CsvTitle(int _column_index = 0, string _title = "") : column_index(_column_index), title(_title) {}
};

template <typename T>
class MiniMatrix2d {
 public:
  T data[];
  int size_x;
  int size_y;

  MiniMatrix2d(int _size_x, int _size_y) : size_x(_size_x), size_y(_size_y) { ArrayResize(data, _size_x * _size_y); }

  T Get(int _x, int _y) { return data[(size_x * _y) + _x]; }

  void Set(int _x, int _y, T _value) { data[(size_x * _y) + _x] = _value; }

  int SizeX() { return size_x; }

  int SizeY() { return size_y; }
};

enum ENUM_SERIALIZER_CSV_FLAGS { SERIALIZER_CSV_INCLUDE_TITLES = 1 };

class SerializerCsv {
 public:
  static string Stringify(SerializerNode* _root, unsigned int serializer_flags = 0, void* serializer_aux_arg = NULL) {
    SerializerConverter* _stub = (SerializerConverter*)serializer_aux_arg;

    if (_stub == NULL) {
      Alert("SerializerCsv: Cannot convert to CSV without stub object!");
      return NULL;
    }

    bool _include_titles = bool(serializer_flags & SERIALIZER_CSV_INCLUDE_TITLES);

    unsigned int _num_columns =
        MathMax(_stub.Node().MaximumNumChildrenInDeepEnd(), _root.MaximumNumChildrenInDeepEnd());
    unsigned int _num_rows = _root.IsArray() ? _root.NumChildren() : _root.NumChildren() > 0 ? 1 : 0;

    if (_include_titles) {
      ++_num_rows;
    }

    MiniMatrix2d<string> _cells(_num_columns, _num_rows);

    Print("Stub: ", _stub.Node().ToString());
    Print("Data: ", _root.ToString());
    Print("Size: ", _num_columns, " x ", _num_rows);

    if (!SerializerCsv::FlattenNode(_root, _stub.Node(), _cells, 0, _include_titles ? 1 : 0, _include_titles)) {
      Alert("SerializerCsv: Error occured during flattening!");
    }

    string _result;

    for (int y = 0; y < _cells.SizeY(); ++y) {
      for (int x = 0; x < _cells.SizeX(); ++x) {
        _result += _cells.Get(x, y);

        if (x != _cells.SizeX() - 1) {
          _result += ",";
        }
      }
      _result += "\n";
    }

    _stub.Clean();

    return _result;
  }

  static string ParamToString(SerializerNodeParam* param) {
    switch (param.GetType()) {
      case SerializerNodeParamBool:
      case SerializerNodeParamLong:
      case SerializerNodeParamDouble:
        return param.AsString(false, false, false);
      case SerializerNodeParamString:
        return EscapeString(param.AsString(false, false, false));
    }

    return "";
  }

  static string EscapeString(string _value) {
    string _result = _value;
    StringReplace(_result, "\"", "\"\"");
    return "\"" + _result + "\"";
  }

  /**
   *
   */
  static bool FlattenNode(SerializerNode* _data, SerializerNode* _stub, MiniMatrix2d<string>& _cells, int _column = 0,
                          int _row = 0, bool _include_titles = false) {
    unsigned int _data_entry_idx;

    if (_stub.IsArray()) {
      for (_data_entry_idx = 0; _data_entry_idx < _data.NumChildren(); ++_data_entry_idx) {
        if (!SerializerCsv::FillRow(_data.GetChild(_data_entry_idx), _stub.GetChild(0), _cells, _column,
                                    _row + _data_entry_idx, 0, 0, _include_titles)) {
          return false;
        }
      }
    } else if (_stub.IsObject()) {
      // Object means that there is only one row.
      unsigned int _entry_size = _stub.MaximumNumChildrenInDeepEnd();

      for (_data_entry_idx = 0; _data_entry_idx < _data.NumChildren(); ++_data_entry_idx) {
        if (!SerializerCsv::FillRow(_data.GetChild(_data_entry_idx), _stub, _cells,
                                    _column + _data_entry_idx * _entry_size, _row, 0, 0, _include_titles)) {
          return false;
        }
      }
    }

    return true;
  }

  /**
   *
   */
  static bool FillRow(SerializerNode* _data, SerializerNode* _stub, MiniMatrix2d<string>& _cells, int _column, int _row,
                      int _index = 0, int _level = 0, bool _include_titles = false) {
    unsigned int _data_entry_idx, _entry_size;

    if (_data.IsObject()) {
      for (_data_entry_idx = 0; _data_entry_idx < _data.NumChildren(); ++_data_entry_idx) {
        _entry_size = _data.GetChild(_data_entry_idx).TotalNumChildren();

        if (!SerializerCsv::FillRow(_data.GetChild(_data_entry_idx),
                                    _stub != NULL ? _stub.GetChild(_data_entry_idx) : NULL, _cells, _column, _row,
                                    _data_entry_idx, _level + 1, _include_titles)) {
          return false;
        }

        _column += (int)_entry_size;
      }
    } else if (_data.IsArray()) {
      for (_data_entry_idx = 0; _data_entry_idx < _data.NumChildren(); ++_data_entry_idx) {
        _entry_size = _stub.MaximumNumChildrenInDeepEnd();

        if (!SerializerCsv::FillRow(_data.GetChild(_data_entry_idx), _stub.GetChild(0), _cells,
                                    _column + _data_entry_idx * _entry_size, _row, _data_entry_idx, _level + 1,
                                    _include_titles)) {
          return false;
        }
      }
    } else {
      // A property.
      if (_include_titles && StringLen(_cells.Get(_column, _row - 1)) == 0) {
        // Creating fully qualified title.
        string _fqt = "";

        for (SerializerNode* node = _data; node != NULL; node = node.GetParent()) {
          if (node.HasKey()) {
            if (_fqt == "") {
              _fqt = node.Key();
            } else {
              _fqt = node.Key() + "." + _fqt;
            }
          }
        }
        _cells.Set(_column, 0, EscapeString(_fqt));
      }

      _cells.Set(_column, _row, ParamToString(_data.GetValueParam()));
    }

    return true;
  }
};

#endif
